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
    
    var audioSession: AVAudioSession!
    var meterTimer: CADisplayLink?
    var peakAudioLevel: Int16 = 0
    var audioEngine = AVAudioEngine()
    var converter:AVAudioConverter?
    var audioUnit: AudioComponentInstance?
    var freeDvApi = FreeDVApi()
    var audioOutputFile:FileHandle?
    var quittingTime = false    // used to stop the player
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
      audioSession = AVAudioSession.sharedInstance()
      do {
        // AVAudioSessionCategoryMultiRoute
        // AVAudioVoiceChat...
        try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, mode: AVAudioSessionModeDefault, options: [.allowBluetooth, .allowAirPlay, .allowBluetoothA2DP])
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
            start_rx();
        }
//        startAudioUnitPlayer()
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
                self.audioEngine = AVAudioEngine()
                let inputNode = self.audioEngine.inputNode
                let freeDvAudioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 8000, channels: 1, interleaved: false)
                
                // For some reason I need this extra mixer or I get 2 channels when I only want 1
                let mixer = AVAudioMixerNode()
                self.audioEngine.attach(mixer)
                self.audioEngine.connect(inputNode, to: mixer, format: inputNode.inputFormat(forBus: 0))
                
                let mainMixer = self.audioEngine.mainMixerNode
                self.audioEngine.connect(mixer, to: mainMixer, format: freeDvAudioFormat)
                
                mixer.installTap(onBus: 0, bufferSize: 1024, format: freeDvAudioFormat, block:self.tapCallback(buffer:time:))

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
    func tapCallback(buffer: AVAudioPCMBuffer!, time: AVAudioTime!) {
        let frameLength = Int(buffer!.frameLength)
        if formatShown == false {
            formatShown = true
            let channelCount = buffer.format.channelCount
            print("#### format = \(buffer.format), channelCount = \(channelCount), frameLength = \(frameLength)")
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
            //let buffPtr = UnsafeMutablePointer(&samples)
            let buffLength = Int(frameLength) * MemoryLayout<Int16>.stride
            fifo_write(gAudioCaptureFifo, samples, Int32(buffLength))
            // write to file as a test
            //let audioData = Data(bytes: buffPtr, count: buffLength)
            //self.audioOutputFile?.write(audioData)
        } else {
            print("Error didn't find Float audio data")
        }
    }
    
    func stopRecorder() {
        self.audioEngine.stop()
    }
    
    
    // ported from code linked via https://stackoverflow.com/questions/14448127/ios-playing-pcm-buffers-from-a-stream
    // helpful https://github.com/GoogleCloudPlatform/ios-docs-samples/blob/master/dialogflow/stopwatch/Stopwatch/AudioController.swift
    func startAudioUnitPlayer() {
        // Describe audio component
        var desc = AudioComponentDescription()
        desc.componentType = kAudioUnitType_Output
        desc.componentSubType = kAudioUnitSubType_RemoteIO
        desc.componentFlags = 0
        desc.componentFlagsMask = 0
        desc.componentManufacturer = kAudioUnitManufacturer_Apple
        
        // Get component
        let inputComponent = AudioComponentFindNext(nil, &desc)!
        
        // Get audio units
        var status = AudioComponentInstanceNew(inputComponent, &audioUnit)
        if status != noErr {
            print("error in AudioComponentInstanceNew = \(status)")
            return
        }
        
        let kInputBus:UInt32 = 1
        let kOutputBus:UInt32 = 0
        
        // Enable IO for recording
        var flag:UInt32 = 1
        status = AudioUnitSetProperty(audioUnit!,
                                        kAudioOutputUnitProperty_EnableIO,
                                        kAudioUnitScope_Input,
                                        kInputBus,
                                        &flag,
                                        UInt32(MemoryLayout<UInt32>.size) )
        if status != noErr {
            print("error in AudioUnitSetProperty in = \(status)")
            return
        }
        
        // Enable IO for playback
        flag = 1
        status = AudioUnitSetProperty(audioUnit!,
                                        kAudioOutputUnitProperty_EnableIO,
                                        kAudioUnitScope_Output,
                                        kOutputBus,
                                        &flag,
                                        UInt32(MemoryLayout<UInt32>.size) )
        if status != noErr {
            print("error in AudioUnitSetProperty out = \(status)")
            return
        }
        
        // Describe format
        var audioFormat = AudioStreamBasicDescription()
        audioFormat.mSampleRate            = 44100.00;
        audioFormat.mFormatID            = kAudioFormatLinearPCM;
        audioFormat.mFormatFlags        = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        audioFormat.mFramesPerPacket    = 1;
        audioFormat.mChannelsPerFrame    = 1;
        audioFormat.mBitsPerChannel        = 16;
        audioFormat.mBytesPerPacket        = 2;
        audioFormat.mBytesPerFrame        = 2;
        
        // Apply format
        status = AudioUnitSetProperty(audioUnit!,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Output,
                                      kInputBus,
                                      &audioFormat,
                                      UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        if status != noErr {
            print("error in AudioUnitSetProperty format = \(status)")
            return
        }
        
        status = AudioUnitSetProperty(audioUnit!,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Input,
                                      kOutputBus,
                                      &audioFormat,
                                      UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        if status != noErr {
            print("error in AudioUnitSetProperty format 2 = \(status)")
            return
        }
        
        // Set output callback
        var callbackStruct = AURenderCallbackStruct()
        callbackStruct.inputProc = (renderCallback)
        callbackStruct.inputProcRefCon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        status = AudioUnitSetProperty(audioUnit!,
                                      kAudioUnitProperty_SetRenderCallback,
                                      kAudioUnitScope_Global,
                                      kOutputBus,
                                      &callbackStruct,
                                      UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        // https://stackoverflow.com/questions/33715628/aurendercallback-in-swift
        // this next attempt crashes
        // status = AudioUnitAddRenderNotify(audioUnit!, renderCallback as! AURenderCallback, Unmanaged.passUnretained(self).toOpaque())
        if status != noErr {
            print("error in AudioUnitAddRenderNotify = \(status)")
            return
        }
        
        status = AudioUnitInitialize(audioUnit!)
        if status != noErr {
            print("error in AudioUnitInitialize = \(status)")
            return
        }
        
        status = AudioOutputUnitStart(audioUnit!)
        if status != noErr {
            print("error in AudioOutputUnitStart = \(status)")
            return
        }
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
