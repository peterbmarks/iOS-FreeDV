//
//  ViewController.swift
//  FreeDV
//
//  Created by Peter Marks on 3/6/18.
//  Copyright © 2018 Peter Marks. All rights reserved.
//
// https://developer.apple.com/audio/
// Thanks: https://www.hackingwithswift.com/example-code/media/how-to-record-audio-using-avaudiorecorder
// Thanks: https://developer.apple.com/library/content/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/AudioSessionBasics/AudioSessionBasics.html
// Thanks: https://www.raywenderlich.com/185090/avaudioengine-tutorial-for-ios-getting-started
// https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/Introduction/Introduction.html#//apple_ref/doc/uid/TP40007875
// play -t raw -r 8000 -e signed-integer -b 16 audio8kPCM16.raw 

import UIKit
import AVFoundation

// used to print the audio format just once per run
var formatShown = false

class ViewController: UIViewController, AVAudioRecorderDelegate {

    @IBOutlet weak var startSwitch: UISwitch!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var audioLevelProgressView: UIProgressView!
    @IBOutlet weak var syncLightView: UIView!
    @IBOutlet weak var snrProgressView: UIProgressView!
    @IBOutlet weak var textMessageLabel: UILabel!
    @IBOutlet weak var spectrumView: SpectrumView!
    @IBOutlet weak var audioFormatLabel: UILabel!
    
    let audioController = AudioController()
    var meterTimer: CADisplayLink?
    var peakAudioLevel: Int16 = 0
    var freeDvApi = FreeDVApi()
    var audioOutputFile:FileHandle?
    var quittingTime = false    // used to stop the player
    
  override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.spectrumView.setRingBuffersArray(audioController.ringBuffers)
        self.spectrumView.setSpectrumAnalyzer(audioController.spectrumAnalyzer)
    
        func listAvailableAudioSessionCategories(audioSession: AVAudioSession) {
            print("Listing available audio session categories...")
            for category in audioSession.availableCategories {
                print("category = \(category)")
            }
        }
    }
    

  // start receiving
  @IBAction func onStartSwitchChanged(_ sender: UISwitch) {
    print("Start switch changed")
    if sender.isOn == true {
        print("audio started")
        rx_init()
        startAudioCapture()
        startAudioMetering()
        DispatchQueue.global(qos: .userInitiated).async {
            start_rx()
        }
        startDecodePlayer() // pulls decoded samples from the fifo
    } else {
        print("audio stopped")
        stopRecorder()
        stopAudioMetering()
        stopPlayer()
        stop_rx()   // call to c routine in FreeDVrx.c
    }
  }
  
  func startAudioMetering() {
    self.meterTimer = CADisplayLink(target: self, selector: #selector(ViewController.updateMeter))
    self.meterTimer?.add(to: .current, forMode: RunLoop.Mode.default)
    self.meterTimer?.preferredFramesPerSecond = 20
    //self.meterTimer?.isPaused = true
  }
  
  func stopAudioMetering() {
    self.meterTimer?.invalidate()
    self.audioLevelProgressView.progress = 0.0
    self.peakAudioLevel = 0
    self.snrProgressView.progress = 0.0
  }
  
  @objc func updateMeter() {
    // print("peakLevel = \(self.peakAudioLevel)")
    // convert from Integer range to 0-1.0
    let peakLevel = Float(audioController.peakAudioLevel) * 100.0 / Float(Int16.max)
    let logPeakLevel = (log10(peakLevel) + 1) * 0.33
    self.audioLevelProgressView.progress = logPeakLevel
    
    let snr = String(format:"%.3f", gSnr_est)
    let bitErr = gTotal_bit_errors
    self.statusLabel.text = "bit errors = \(bitErr), snr = \(snr)"
    updateSyncLight()
    updateSnrMeter()
    updateTextMessage()
    self.audioFormatLabel.text = self.audioController.formatText
  }
    
    func updateSyncLight() {
        if gSync == 0 {
            self.syncLightView.backgroundColor = UIColor.red
        } else if gSync == 1 {
            self.syncLightView.backgroundColor = UIColor.green
        }
    }
    
    func updateSnrMeter() {
        // values range from -10 to 0 presumably
        var zeroToOneSnr = (10.0 + gSnr_est) / 10.0
        if zeroToOneSnr > 1.0 {
            zeroToOneSnr = 1.0
        }
        self.snrProgressView.progress = zeroToOneSnr;
    }
    
    func updateTextMessage() {
        let message = String(cString: gTextMessageBuffer)
        self.textMessageLabel.text = message
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

extension ViewController {
    func startAudioCapture() {
       audioController.startCapture()
    }
    /*
    // closure called from the mixer tap on input audio
    // the job here is to convert the audio samples to the format FreeDV codec2 wants and
    // put them into the fifo
    func captureTapCallback(buffer: AVAudioPCMBuffer!, time: AVAudioTime!) {
        let frameLength = Int(buffer!.frameLength)
        if formatShown == false {
            formatShown = true
            let channelCount = buffer.format.channelCount
            print("#### format = \(buffer.format), channelCount = \(channelCount), frameLength = \(frameLength)")
            let gain = audioSession.inputGain
            print("input gain = \(gain)")
        }
        
        if buffer!.floatChannelData != nil {
            let dataPtrPtr = buffer.floatChannelData
            let elements = dataPtrPtr?.pointee
            
            //var samples = [Int16](repeating: 0, count: frameLength)
            let samples = UnsafeMutablePointer<Int16>.allocate(capacity: frameLength)
            for i in 0..<frameLength {
                let floatSample = elements![i]
                let intSample = Int16(floatSample * 32768.0)
                samples[i] = intSample
            }
            self.peakAudioLevel = self.computePeakAudioLevel(samples: samples, count: frameLength)
            let buffLength = Int(frameLength) * MemoryLayout<Int16>.stride
            fifo_write(gAudioCaptureFifo, samples, Int32(buffLength))
            
            // write into the ring buffers for the spectrum display
            self.ringBuffers[0].pushSamples(buffer!.floatChannelData!.pointee, count: UInt(frameLength))
        } else {
            print("Error didn't find Float audio data")
        }
    }
    */
    func stopRecorder() {
        audioController.stopCapture()
    }
    
    func stopPlayer() {
        self.quittingTime = true
    }
    
    func urlToFileInDocumentsDirectory(fileName: String) -> URL {
        let nsDocumentDirectory = FileManager.SearchPathDirectory.documentDirectory
        let nsUserDomainMask    = FileManager.SearchPathDomainMask.userDomainMask
        let paths               = NSSearchPathForDirectoriesInDomains(nsDocumentDirectory, nsUserDomainMask, true)
        let dirPath          = paths.first
        let fileURL = URL(fileURLWithPath: dirPath!).appendingPathComponent(fileName)
        return fileURL
    }
}

// MARK: Play decoded audio
// play -r 8000 -t raw -r 8k -e signed -b 16 -c 1 decoded.raw
extension ViewController {
    func startDecodePlayer() {
        let fileUrl = urlToFileInDocumentsDirectory(fileName: "decoded.raw")
        
        do {
            if FileManager.default.fileExists(atPath: fileUrl.path) == true {
                print("Deleting file")
                try FileManager.default.removeItem(at: fileUrl)
                print("File deleted")
            }
            print("creating file")
            FileManager.default.createFile(atPath: fileUrl.path, contents: nil, attributes: nil)
            print("writing decoded audio to \(fileUrl.path)")
            
            let outfile = try FileHandle(forWritingTo: fileUrl)
            DispatchQueue.global(qos: .userInitiated).async {
                while self.quittingTime == false {
                    let availableSamples = fifo_used(gAudioDecodedFifo)
                    if availableSamples > 0 {
                        let audioBuffer = UnsafeMutablePointer<Int16>.allocate(capacity: Int(availableSamples))
                        if fifo_read(gAudioDecodedFifo, audioBuffer, Int32(availableSamples)) != -1 {
                            let byteLength = Int(MemoryLayout<Int16>.size * Int(availableSamples))
                            outfile.write(Data(bytes: audioBuffer, count: byteLength))
                        } else {
                            print("Error reading from fifo")
                        }
                        audioBuffer.deallocate()
                        // print("got \(availableSamples) of decoded audio")
                    } else {
                        usleep(500)
                    }
                }
                print("decodePlayer finishing")
                outfile.closeFile()
            }
        } catch {
            print("Error opening audio output file \(error)")
        }

    }
}

// called when audio is needed
// https://stackoverflow.com/questions/33715628/aurendercallback-in-swift
// http://pulkitgoyal.in/audio-processing-on-ios-using-aubio/
let renderCallback: AURenderCallback = {(inRefCon,
                                            ioActionFlags,
                                            inTimeStamp,
                                            inBusNumber,
                                            frameCount,
                                            ioData) -> OSStatus in
    let kBufferSize:Int = 1024
    // allocate a buffer. we are responsible for deallocating
    var audioBuffer = UnsafeMutablePointer<Int16>.allocate(capacity: kBufferSize)
    var availableSamples = fifo_used(gAudioDecodedFifo)
    if availableSamples > kBufferSize {
        availableSamples = Int32(kBufferSize)
    }
    let buffLength = Int(availableSamples) * MemoryLayout<Int16>.stride
    fifo_read(gAudioDecodedFifo, audioBuffer, Int32(buffLength))
    var ioPtr = UnsafeMutableAudioBufferListPointer(ioData)!
    let actualAudioBuffer = AudioBuffer(mNumberChannels: 1, mDataByteSize: 16, mData: &audioBuffer)
    ioPtr[0] = actualAudioBuffer
    ioPtr.count = 1
    return 0
}
