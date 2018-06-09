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
    var audioRecorder: AVAudioRecorder!
    var isTransmitting = false
    var meterTimer: Timer?
    var audioEngine = AVAudioEngine()
    var radioOutPlayerNode = AVAudioPlayerNode()
    var radioOutBuffer :AVAudioPCMBuffer?
    var audioController: AudioController?
    
    var radioIn = AVAudioRecorder()
  
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
          break
        }
      case .oldDeviceUnavailable:
        if let previousRoute =
          userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
          for output in previousRoute.outputs where output.portType == AVAudioSessionPortHeadphones {
            //headphonesConnected = false
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
        audioController = AudioController()
        audioController!.startIOUnit()
        audioController!.muteAudio = false
    } else {
        print("audio stopped")
        audioController!.stopIOUnit()
        audioController = nil
    }
  }
  
  @IBAction func onToRadioButton(_ sender: UIButton) {
    // storyboard segues is used to open the modal vc
    print("Tapped the To radio audio button")
  }
  
  @IBAction func onFromRadioButton(_ sender: UIButton) {
    // storyboard segues is used to open the modal vc
    print("Tapped the From radio audio button")
  }
  
  @IBAction func transmitSwitchAction(_ sender: UISwitch) {
    print("Transmit switch changed")
    if sender.isOn == true {
      print("started transmitting")
      audioSession.requestRecordPermission() { [unowned self] allowed in
          DispatchQueue.main.async {
            if allowed {
              self.startRecording()
            } else {
              // failed to record!
              self.statusLabel.text = "Needs permission to access microphone"
            }
          }
        }
    } else {
      finishRecording(success: true)
    }
  }
  
  // For more: https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/OptimizingForDeviceHardware/OptimizingForDeviceHardware.html#//apple_ref/doc/uid/TP40007875-CH6-SW1
  func startRecording () {
    let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
    
    let settings = [
      AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
      AVSampleRateKey: 44_100,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
    
    do {
      audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
      audioRecorder.delegate = self
      audioRecorder.prepareToRecord()
      audioRecorder.isMeteringEnabled = true
      audioRecorder.record()
      self.startAudioMetering()
    } catch {
      finishRecording(success: false)
    }
  }
  
  func finishRecording(success: Bool) {
    stopAudioMetering()
    audioRecorder.stop()
    audioRecorder = nil
    
    if success {
      //recordButton.setTitle("Tap to Re-record", for: .normal)
    } else {
      //recordButton.setTitle("Tap to Record", for: .normal)
      // recording failed :(
    }
  }
  
  // delegate that might be called by iOS to stop us
  func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
    if !flag {
      finishRecording(success: false)
    }
  }
  
  func startAudioMetering() {
    self.meterTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(ViewController.updateMeter), userInfo: nil, repeats: true)
  }
  
  func stopAudioMetering() {
    self.meterTimer?.invalidate()
    self.audioLevelProgressView.progress = 0.0
  }
  
  @objc func updateMeter() {
    self.audioRecorder.updateMeters()
    let peakLevel = self.audioRecorder.peakPower(forChannel: 0)
    //print("peakLevel = \(peakLevel)")
    // I see db levels of -30 to 0
    let meterLevel = peakLevel + 30.0
    self.audioLevelProgressView.progress = meterLevel / 30.0
  }
    
  func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "chooseOutput" {
      print("choose radio output")
      //let radioOutput = segue.destination as! ChooseOutVC
    } else if segue.identifier == "chooseInput" {
      //let radioInput = segue.destination as! ChooseInVC
    }
  }
}

