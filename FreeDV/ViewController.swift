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
    
    var audioSession: AVAudioSession!
    var meterTimer: CADisplayLink?
    var peakAudioLevel: Int16 = 0
    var audioEngine = AVAudioEngine()
    var converter:AVAudioConverter?
    var audioUnit: AudioComponentInstance?
    var freeDvApi = FreeDVApi()
    var audioOutputFile:FileHandle?
    var quittingTime = false    // used to stop the player
    
    var ringBuffers = [AudioRingBuffer]()
    let spectrumAnalyzer = SpectrumAnalyzer()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    self.ringBuffers.append(AudioRingBuffer())
    self.spectrumView.setRingBuffersArray(self.ringBuffers)
    self.spectrumView.setSpectrumAnalyzer(self.spectrumAnalyzer) 
    
    audioSession = AVAudioSession.sharedInstance()
    listAvailableAudioSessionCategories(audioSession:audioSession)
    listAvailableInputs(audioSession)
    printCurrentInput(audioSession:audioSession)
    do {
    // AVAudioSessionCategoryMultiRoute
    // AVAudioVoiceChat...
    try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
    print("Audio category set ok")
    try audioSession.setPreferredSampleRate(8000)   // this is ignored but I thought I'd try
    print("preferred Sample rate set")
    try audioSession.setActive(true)
    } catch {
        print("Error starting audio session")
        print("Error info: \(error)")
    }

    NotificationCenter.default.addObserver(self, selector: #selector(ViewController.handleInterruptionNotification(notification:)), name: .AVAudioSessionInterruption, object: nil)

    NotificationCenter.default.addObserver(self, selector: #selector(ViewController.handleRouteChangedNotification(notification:)), name: .AVAudioSessionRouteChange, object: nil)
    }
    
    func listAvailableAudioSessionCategories(audioSession: AVAudioSession) {
        print("Listing available audio session categories...")
        for category in audioSession.availableCategories {
            print("category = \(category)")
        }
    }
    
    // look through the available inputs and try to find one with USB in it
    // if found set that as preferred
    func setPreferredInputToUsb(audioSession:AVAudioSession) {
        for audioSessionPortDescription in audioSession.availableInputs! {
            //let deviceId = audioSessionPortDescription
            let name = audioSessionPortDescription.portName
            let portType = audioSessionPortDescription.portType
            print("port name = \(name), portType = \(portType)")
            if portType == AVAudioSessionPortUSBAudio { 
                print("Found 'USBAudio'")
                do {
                    try audioSession.setPreferredInput(audioSessionPortDescription)
                    print("set preferred input to USB")
                    printCurrentInput(audioSession: audioSession)
                } catch {
                    print("Error setting preferred Input = \(error)")
                }
            }
        }
    }
    // MARK: debug
    func printCurrentInput(audioSession:AVAudioSession) {
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
    
    func listAvailableInputs(_ audioSession: AVAudioSession) {
        let route = audioSession.currentRoute
        print("currrent route = \(route)")
        for audioSessionPortDescription in audioSession.availableInputs! {
            let name = audioSessionPortDescription.portName
            let portType = audioSessionPortDescription.portType // MicrophoneBuiltIn, MicrophoneWired, USBAudio
            print("port name = \(name), port type = \(portType)")
            if let dataSources = audioSessionPortDescription.dataSources {
                for dataSource in dataSources {
                    print(" dataSource = \(dataSource)")
                }
            }
        }
    }
    
    @objc func handleInterruptionNotification(notification: NSNotification) {
        let interruptionType = notification.userInfo![AVAudioSessionInterruptionTypeKey] as! AVAudioSessionInterruptionType
        
        if interruptionType == AVAudioSessionInterruptionType.began {
            // session is now inactive and playback is paused
            print("audio interruption notification")
            startSwitch.isOn = false
        } else {
            print("audio interruption ended")
        }
    }
  
  // https://developer.apple.com/documentation/avfoundation/avaudiosession/responding_to_audio_session_route_changes
    @objc func handleRouteChangedNotification(notification: NSNotification) {
      guard let userInfo = notification.userInfo,
        let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
        let reason = AVAudioSessionRouteChangeReason(rawValue:reasonValue) else {
          return
      }
      switch reason {
      case .newDeviceAvailable:
        let session = AVAudioSession.sharedInstance()
        for output in session.currentRoute.outputs where output.portType == AVAudioSessionPortHeadphones {
          //headphonesConnected = true
            print("new device available")
          break
        }
      case .oldDeviceUnavailable:
        if let previousRoute =
          userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
          for output in previousRoute.outputs where output.portType == AVAudioSessionPortHeadphones {
            //headphonesConnected = false
            print("old device unavailable")
            break
          }
        }
      default: ()
      }
        listAvailableInputs(AVAudioSession.sharedInstance())
        setPreferredInputToUsb(audioSession: AVAudioSession.sharedInstance())
    }
    
  override func viewDidAppear(_ animated: Bool) {
  }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
    self.meterTimer?.add(to: .current, forMode: .defaultRunLoopMode)
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
    self.audioLevelProgressView.progress = Float(self.peakAudioLevel) * 3.0 / Float(Int16.max)
    
    self.statusLabel.text = "sync = \(gSync), snr = \(gSnr_est), bit err = \(gTotal_bit_errors)"
    updateSyncLight()
    updateSnrMeter()
    updateTextMessage()
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
        audioSession.requestRecordPermission { (granted) in
            if granted {
                print("start audio capture")
                let audioSession = AVAudioSession.sharedInstance()
                self.setPreferredInputToUsb(audioSession:audioSession)
                self.printCurrentInput(audioSession:audioSession)
                
                self.audioEngine = AVAudioEngine()
                let inputNode = self.audioEngine.inputNode
                //let audioUnit = inputNode.audioUnit
                
                let mixer1 = AVAudioMixerNode()
                self.audioEngine.attach(mixer1)
                self.audioEngine.connect(inputNode, to: mixer1, format: inputNode.inputFormat(forBus: 0))
                
                let mixer2 = AVAudioMixerNode()
                self.audioEngine.attach(mixer2)
                let freeDvAudioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 8000, channels: 1, interleaved: false)
                self.audioEngine.connect(mixer1, to: mixer2, format: freeDvAudioFormat)
                
                mixer1.installTap(onBus: 0, bufferSize: 1024, format: freeDvAudioFormat, block:self.captureTapCallback(buffer:time:))
                
                //let decodedFreeDvAudioPlayer = AVAudioPlayer()
                var gain = inputNode.volume
                print("input node volume = \(gain)")
                gain = mixer1.volume
                print("mixer1 volume = \(gain)")
                gain = mixer1.outputVolume
                print("mixer1 outputVolume = \(gain)")
                gain = mixer2.volume
                print("mixer2 volume = \(gain)")
                gain = mixer2.outputVolume
                print("mixer2 outputVolume = \(gain)")
                
                let mainMixer = self.audioEngine.mainMixerNode
                self.audioEngine.connect(mixer1, to: mainMixer, format: freeDvAudioFormat)

                gain = mainMixer.volume
                print("mainMixer volume = \(gain)")
                gain = mainMixer.outputVolume
                print("mainMixer outputVolume = \(gain)")
                
                do {
                    try self.audioEngine.start()
                } catch let error {
                    print(error.localizedDescription)
                }
                print("started audio")
            }
        }
    }
    
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
    
    func stopRecorder() {
        self.audioEngine.stop()
    }
    
    // https://stackoverflow.com/questions/42015669/ios-how-to-read-audio-from-a-stream-and-play-the-audio
    func audioBufferToNSData(PCMBuffer: AVAudioPCMBuffer) -> NSData {
        let channelCount = 1  // given PCMBuffer channel count is 1
        let channels = UnsafeBufferPointer(start: PCMBuffer.int16ChannelData, count: channelCount)
        let data = NSData(bytes: channels[0], length:Int(PCMBuffer.frameLength * PCMBuffer.format.streamDescription.pointee.mBytesPerFrame))
        
        return data
    }
    
    func dataToPCMBuffer(format: AVAudioFormat, data: NSData) -> AVAudioPCMBuffer {
        
        let audioBuffer = AVAudioPCMBuffer(pcmFormat: format,
                                           frameCapacity: UInt32(data.length) / format.streamDescription.pointee.mBytesPerFrame)!
        
        audioBuffer.frameLength = audioBuffer.frameCapacity
        let channels = UnsafeBufferPointer(start: audioBuffer.int16ChannelData, count: Int(audioBuffer.format.channelCount))
        data.getBytes(UnsafeMutableRawPointer(channels[0]) , length: data.length)
        return audioBuffer
    }
    
    func stopPlayer() {
        self.quittingTime = true
        if audioUnit != nil {
            AudioOutputUnitStop(audioUnit!)
        }
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
