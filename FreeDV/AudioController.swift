//
//  AudioController.swift
//  UsbAudio
//
//  Created by Peter Marks on 29/6/18.
//  Copyright © 2018 Peter Marks. All rights reserved.
//

import UIKit
import AVFoundation

class AudioController: NSObject {
    var audioSession = AVAudioSession.sharedInstance()
    var audioEngine = AVAudioEngine()
    var peakAudioLevel: Int16 = 0
    var quittingTime = false
    var formatShown = false
    var formatText = ""
    var sampleRateRatio: Int = 1
    let freeDvSampleRate = 8000
    var ringBuffers = [AudioRingBuffer]()
    let spectrumAnalyzer = SpectrumAnalyzer()
    
    override init() {
        super.init()
        print("AudioController.init()")
        self.ringBuffers.append(AudioRingBuffer())
        printCurrentRoute()
        
        NotificationCenter.default.addObserver(self, selector: #selector(AudioController.handleInterruptionNotification(notification:)), name: AVAudioSession.interruptionNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(AudioController.handleRouteChangedNotification(notification:)), name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    func setupAudioSession() {
        do {
            try audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: AVAudioSession.Mode.default, options: [])
            print("Audio category set ok")
            try audioSession.setPreferredSampleRate(8000)   // this is ignored but it sets it to 16000
            print("preferred Sample rate set")
            try audioSession.setPreferredInputNumberOfChannels(1)   // this gets ignored too
            try audioSession.setActive(true)
        } catch {
            print("Error starting audio session")
            print("Error info: \(error)")
        }
    }
    
    func startCapture() {
        setupAudioSession()
        formatShown = false
        audioSession.requestRecordPermission { (granted) in
            if granted {
                print("start audio capture")
                do {
                    let inputNode = self.audioEngine.inputNode
                    inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.inputFormat(forBus: 0), block:self.captureTapCallback(buffer:time:))
                    try self.audioEngine.start()
                } catch let error {
                    print(error.localizedDescription)
                }
                print("started audio")
            }
        }
    }
    
    func stopCapture() {
        quittingTime = true
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        peakAudioLevel = 0
    }
    
    // closure called from the mixer tap on input audio
    // the job here is to convert the audio samples to the format FreeDV codec2 wants and
    // put them into the fifo
    func captureTapCallback(buffer: AVAudioPCMBuffer!, time: AVAudioTime!) {
        let frameLength = Int(buffer!.frameLength)
        if formatShown == false {
            formatShown = true
            let channelCount = buffer.format.channelCount
            self.formatText = "format = \(buffer.format), channelCount = \(channelCount), frameLength = \(frameLength)"
            let sampleRate = Int(buffer.format.sampleRate)
            sampleRateRatio = sampleRate * Int(channelCount) / freeDvSampleRate
            print("sample rate ratio is \(sampleRateRatio)")
        }
        
        if buffer!.floatChannelData != nil {
            let dataPtrPtr = buffer.floatChannelData
            let elements = dataPtrPtr?.pointee
            let downSampleCount = frameLength / sampleRateRatio
            let samples = UnsafeMutablePointer<Int16>.allocate(capacity: downSampleCount)
            let samplesFloat = UnsafeMutablePointer<Float>.allocate(capacity: downSampleCount)
            var downSampleIndex = 0
            for i in 0..<frameLength {
                if i % sampleRateRatio == 0 {
                    let floatSample = elements![i]
                    samplesFloat[downSampleIndex] = floatSample
                    let intSample = Int16(floatSample * Float(Int16.max))
                    samples[downSampleIndex] = intSample
                    downSampleIndex += 1
                }
            }
            self.peakAudioLevel = self.computePeakAudioLevel(samples: samples, count: downSampleCount)
            let buffLength = Int(downSampleCount) * MemoryLayout<Int16>.stride
            fifo_write(gAudioCaptureFifo, samples, Int32(buffLength))
            
            // write into the ring buffers for the spectrum display
            self.ringBuffers[0].pushSamples(samplesFloat, count: UInt(downSampleCount))
            samplesFloat.deallocate()
            
            //let buffLength = Int(frameLength) * MemoryLayout<Int16>.stride
            
            // write into the ring buffers for the spectrum display
            // self.ringBuffers[0].pushSamples(buffer!.floatChannelData!.pointee, count: UInt(frameLength))
        } else {
            print("Error didn't find Float audio data")
        }
    }
    
    func computePeakAudioLevel(samples: UnsafeMutablePointer<Int16>, count: Int) -> Int16 {
        var max:Int16 = 0
        for i in 0..<count {
            let sample = samples[i]
            if sample > max {
                max = sample
            }
        }
        return max
    }
}

// MARK: Audio notifications
extension AudioController {
    @objc func handleInterruptionNotification(notification: NSNotification) {
        let interruptionType = notification.userInfo![AVAudioSessionInterruptionTypeKey] as! AVAudioSession.InterruptionType
        
        if interruptionType == AVAudioSession.InterruptionType.began {
            // session is now inactive and playback is paused
            print("audio interruption notification")
        } else {
            print("audio interruption ended")
        }
        formatShown = false
    }
    
    // https://developer.apple.com/documentation/avfoundation/avaudiosession/responding_to_audio_session_route_changes
    @objc func handleRouteChangedNotification(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue:reasonValue) else {
                return
        }
        switch reason {
        case .newDeviceAvailable:
            let session = AVAudioSession.sharedInstance()
            for output in session.currentRoute.outputs where output.portType == AVAudioSession.Port.usbAudio {
                    print("new USB device available")
                break
            }
        case .oldDeviceUnavailable:
            if let previousRoute =
                userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                for output in previousRoute.outputs where output.portType == AVAudioSession.Port.usbAudio {
                    //headphonesConnected = false
                    print("old USB device removed")
                    break
                }
            }
        default: ()
        }
        listAvailableInputs()
        setPreferredInputToUsb()
        printCurrentRoute()
        formatShown = false
    }
}
// MARK: Debug utilities
extension AudioController {
    func listAvailableAudioSessionCategories() {
        print("Listing available audio session categories...")
        for category in audioSession.availableCategories {
            print("category = \(category)")
        }
    }
    
    // look through the available inputs and try to find one with USB in it
    // if found set that as preferred
    func setPreferredInputToUsb() {
        for audioSessionPortDescription in audioSession.availableInputs! {
            //let deviceId = audioSessionPortDescription
            let name = audioSessionPortDescription.portName
            let portType = audioSessionPortDescription.portType
            print("port name = \(name), portType = \(portType)")
            if portType == AVAudioSession.Port.usbAudio {
                print("Found 'USBAudio'")
                do {
                    try audioSession.setPreferredInput(audioSessionPortDescription)
                    print("set preferred input to USB")
                    printCurrentInput()
                } catch {
                    print("Error setting preferred Input = \(error)")
                }
            }
        }
    }
    // MARK: debug
    func printCurrentInput() {
        let input = audioSession.preferredInput
        let name = input?.portName ?? "Not set"
        let gain = audioSession.inputGain
        print("current input = \(name), inputGain = \(gain)")
        do {
            try audioSession.setInputGain(1.0)
        } catch {
            print("Error setting input gain: \(error)")
        }
        print("now inputGain = \(gain)")
    }
    
    func listAvailableInputs() {
        for audioSessionPortDescription in audioSession.availableInputs! {
            let name = audioSessionPortDescription.portName
            let portType = audioSessionPortDescription.portType // MicrophoneBuiltIn, MicrophoneWired, USBAudio
            let portTypeName = portType.rawValue
            print("port name = \(name), port type = \(portTypeName)")
            if let dataSources = audioSessionPortDescription.dataSources {
                for dataSource in dataSources {
                    let dataSourceName = dataSource.dataSourceName
                    print(" data source name = \(dataSourceName)")
                }
            }
        }
    }
    
    func printCurrentRoute() {
        let route = audioSession.currentRoute
        print("currrent route inputs:")
        printInOutList(route.inputs)
        print("currrent route ouputs:")
        printInOutList(route.outputs)
    }
    
    func printInOutList(_ inOrOuts: [AVAudioSessionPortDescription]) {
        for inOrOut in inOrOuts {
            let name = inOrOut.portName
            let type = inOrOut.portType
            let dataSource = inOrOut.selectedDataSource ?? nil
            print(" name: \(name), type: \(type)")
            if dataSource != nil {
                if dataSource?.dataSourceName != nil {
                    let dataSourceName = dataSource?.dataSourceName ?? "No name"
                    print("  selected dataSource: \(dataSourceName)")
                }
            }
        }
    }

}
