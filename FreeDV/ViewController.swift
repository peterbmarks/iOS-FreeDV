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

class ViewController: UIViewController, AVAudioRecorderDelegate {

    @IBOutlet weak var startSwitch: UISwitch!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var audioLevelProgressView: UIProgressView!

    var audioSession: AVAudioSession!
    var meterTimer: CADisplayLink?
    var peakAudioLevel: Int16 = 0
    var audioEngine = AVAudioEngine()
    var converter:AVAudioConverter?
    
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
        startRecorder()
        startAudioMetering()
        DispatchQueue.global(qos: .userInitiated).async {
            start_rx();
        }
        // startPlayer()   // starts a thread that ends when quittingTime == true
        startAudioUnitPlayer()
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
  }
  
  @objc func updateMeter() {
    // print("peakLevel = \(self.peakAudioLevel)")
    self.audioLevelProgressView.progress = Float(self.peakAudioLevel) * 3.0 / Float(Int16.max)
    
    self.statusLabel.text = "sync = \(gSync), snr = \(gSnr_est), bit err = \(gTotal_bit_errors)"
  }
    
    func peakAudioLevel(_ samples: inout [Int16]) -> Int16 {
        var max:Int16 = 0
        for sample in samples {
            if sample > max {
                max = sample
            }
        }
        return max
    }
}

extension ViewController {
    func startRecorder() {
        audioSession.requestRecordPermission { (granted) in
            if granted {
                print("record permission granted")
                self.audioEngine = AVAudioEngine()
                
                let inputNode = self.audioEngine.inputNode
                print("Set intput node")
                /*
                let audioUrl = self.urlToFileInDocumentsDirectory(fileName: "audio8kPCM16.raw")
                if FileManager.default.createFile(atPath: audioUrl.path, contents: nil, attributes: nil) {
                    print("File created")
                }
                print("writing audio to: \(audioUrl.path)")
                do {
                    self.audioOutputFile = try FileHandle(forWritingTo: audioUrl)
                } catch {
                    print("Error opening output audio file: \(error)")
                }
                */
                let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 8000, channels: 1, interleaved: false)
                let mixer = AVAudioMixerNode()
                let mainMixer = self.audioEngine.mainMixerNode
                self.audioEngine.attach(mixer)
                self.audioEngine.connect(inputNode, to: mixer, format: inputNode.inputFormat(forBus: 0))
                //mixer.volume = 0
                self.audioEngine.connect(mixer, to: mainMixer, format: audioFormat)
                self.audioEngine.prepare()
                do {
                    try self.audioEngine.start()
                    var formatShown = false
                    // https://stackoverflow.com/questions/39595444/avaudioengine-downsample-issue
                    // Note that this resampler only works on physical devices
                    mixer.installTap(onBus: 0, bufferSize: 1024, format: audioFormat, block: {
                        (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
                        let frameLength = Int(buffer!.frameLength)
                        if formatShown == false {
                            formatShown = true
                            let channelCount = buffer.format.channelCount
                            print("#### format = \(buffer.format), channelCount = \(channelCount), frameLength = \(frameLength)")
                        }
                        
                        if buffer!.floatChannelData != nil {
                            let dataPtrPtr = buffer.floatChannelData
                            let elements = dataPtrPtr?.pointee
                            
                            var samples = Array<Int16>()
                            for i in 0..<frameLength {
                                let floatSample = elements![i]
                                let intSample = Int16(floatSample * 32768.0)
                                // print("\(i)\t\(floatSample)")
                                samples.append(intSample)
                            }
                            self.peakAudioLevel = self.peakAudioLevel(&samples)
                            let buffPtr = UnsafeMutablePointer(&samples)
                            let buffLength = Int(frameLength) * MemoryLayout<Int16>.stride
                            fifo_write(gAudioCaptureFifo, buffPtr, Int32(buffLength))
                            // write to file as a test
                            //let audioData = Data(bytes: buffPtr, count: buffLength)
                            //self.audioOutputFile?.write(audioData)
                        } else {
                            print("Error didn't find Float audio data")
                        }
                    })
                    
                } catch let error {
                    print(error.localizedDescription)
                }
                print("started audio")
            }
        }
    }
    
    func stopRecorder() {
        self.audioEngine.stop()
    }
    
    // read decoded audio samples from the output fifo and play them
    // 8000 samples 16 bit signed integer
    func startPlayer() {
        self.quittingTime = false
        let kBufferSize = 1000
        var demodInputBuffer = Array<Int16>(repeating: 0, count: kBufferSize)
        //let avAudioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 8000.0, channels: 1, interleaved: false)!
        //let audioEngine: AVAudioEngine = AVAudioEngine()
        //let audioFilePlayer: AVAudioPlayerNode = AVAudioPlayerNode()

        DispatchQueue.global(qos: .userInitiated).async {
            while self.quittingTime == false {
                let availableSamples = fifo_used(gAudioDecodedFifo);
                if(availableSamples >= kBufferSize) {
                    print("player availableSamples = \(availableSamples)")
                    let buffLength = Int(kBufferSize) * MemoryLayout<Int16>.stride
                    fifo_read(gAudioDecodedFifo, &demodInputBuffer, Int32(buffLength))
                    
                    /*
                    let audioData = NSData(bytes: demodInputBuffer, length: buffLength)
                    let avAudioPCMBuffer = self.dataToPCMBuffer(format: avAudioFormat, data: audioData)
                    let mainMixer = audioEngine.mainMixerNode
                    audioEngine.attach(audioFilePlayer)
                    
                    // audioEngine.connect(audioFilePlayer, to:mainMixer, audioFilePlayer.processingFormat)   // throws invalid format exception
                    do {
                        try audioEngine.start()
                    
                        audioFilePlayer.play()
                        audioFilePlayer.scheduleBuffer(avAudioPCMBuffer, completionHandler: {
                            print("finsihed playing segment")
                        })
                    } catch {
                        print("error starting audio engine for play: \(error)")
                    }
                    */
                } else {
                    usleep(200)
                }
            }
        }
    }
    
    // ported from code linked via https://stackoverflow.com/questions/14448127/ios-playing-pcm-buffers-from-a-stream
    // helpful https://github.com/GoogleCloudPlatform/ios-docs-samples/blob/master/dialogflow/stopwatch/Stopwatch/AudioController.swift
    func startAudioUnitPlayer() {
        var audioUnit: AudioComponentInstance? = nil
        var tempBuffer = AudioBuffer() // this will hold the latest data from the microphone
        
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
        callbackStruct.inputProc = (renderCallback as! AURenderCallback)
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
        
        tempBuffer.mNumberChannels = 1
        tempBuffer.mDataByteSize = 512 * 2
        tempBuffer.mData = malloc( 512 * 2 )
        
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
let renderCallback: AURenderCallback = {(inRefCon,
                                            ioActionFlags,
                                            inTimeStamp,
                                            inBusNumber,
                                            frameCount,
                                            ioData) -> OSStatus in
    print("In renderCallback")
    /*
    let delegate = unsafeBitCast(inRefCon, AURenderCallbackDelegate.self)
    let result = delegate.performRender(ioActionFlags,
                                        inTimeStamp: inTimeStamp,
                                        inBusNumber: inBusNumber,
                                        inNumberFrames: inNumberFrames,
                                        ioData: ioData)
 */
    return 0
}
