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
    
    var recordSettings = [
        AVFormatIDKey: NSNumber(value:kAudioFormatLinearPCM),
        AVEncoderAudioQualityKey : AVAudioQuality.high.rawValue,
        AVNumberOfChannelsKey: 1,
        AVSampleRateKey : 44100.0
        ] as [String : Any]
    
    var freeDvApi = FreeDVApi()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
      audioSession = AVAudioSession.sharedInstance()
      do {
        // AVAudioSessionCategoryMultiRoute
        // AVAudioVoiceChat...
        try audioSession.setCategory(AVAudioSessionCategoryMultiRoute)
        // try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, mode: AVAudioSessionModeDefault, options: [.allowBluetooth, .allowAirPlay, .allowBluetoothA2DP])
        print("Audio category set ok")
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
        startRecorder()
        startAudioMetering()
//        freeDvApi.startDecodeFromFileToFile()
    } else {
        print("audio stopped")
        stopRecorder()
        stopAudioMetering()
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
                let mixer = AVAudioMixerNode()
                
                let inputNode = self.audioEngine.inputNode
                print("Set intput node")
                self.audioEngine.attach(mixer)
                self.audioEngine.connect(inputNode, to: mixer, format: inputNode.outputFormat(forBus: 0))

                let bus = 0
                // https://stackoverflow.com/questions/47116933/how-can-i-get-avaudioengine-to-output-pcm-16-from-the-mic

                inputNode.installTap(onBus: bus, bufferSize: 2048, format:inputNode.inputFormat(forBus: bus)) {
                    (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
                    let frameLength = Int(buffer!.frameLength)
                    if buffer!.floatChannelData != nil {
                        let elements = UnsafeBufferPointer(start: buffer.floatChannelData?[0], count:frameLength)
                        // copy samples from the buffer and convert to Int16 for codec2
                        var samples = Array<Int16>()
                        for i in 0..<frameLength {
                            let intSample = Int16(elements[i] * Float(Int16.max))
                            samples.append(intSample)
                        }
                        self.peakAudioLevel = self.peakAudioLevel(&samples)
                    } else {
                        print("Error didn't find Float audio data")
                    }
                }
                
                self.audioEngine.prepare()
                do {
                    try self.audioEngine.start()
                } catch {
                    print("Error starting audio engine = \(error)")
                }
                print("started audio")
            }
        }
    }
    
    func stopRecorder() {
        self.audioEngine.stop()
    }
}
