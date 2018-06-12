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
    var meterTimer: CADisplayLink?
    var audioEngine = AVAudioEngine()
    var radioOutPlayerNode = AVAudioPlayerNode()
    var radioOutBuffer :AVAudioPCMBuffer?
    var audioController: AudioController?
    var audioFile: URL?
    
    var radioIn = AVAudioRecorder()
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
    self.audioFile = setupAudioFile(name: "tempaudio.raw")
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
        startRecorder()
        startPlayer()
//        audioController = AudioController()
//        audioController!.startIOUnit()
//        audioController!.muteAudio = false
//        self.startAudioMetering()
        
//        freeDvApi.startDecodeFromFileToFile()
    } else {
        print("audio stopped")
        stopRecorder()
//        self.stopAudioMetering()
//        audioController!.stopIOUnit()
//        audioController = nil
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
  }
  
  @objc func updateMeter() {
    let peakLevel = audioController?.peakLevel ?? 0.0
    // print("peakLevel = \(peakLevel)")
    self.audioLevelProgressView.progress = peakLevel * 4.0
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

extension ViewController {
    func startRecorder() {
        do {
            print("Removing old audio file")
            try FileManager.default.removeItem(at: self.audioFile!)
        } catch {
            print("Error deleting old audio file: \(error)")
        }
        audioSession.requestRecordPermission { (granted) in
            if granted {
                print("record permission granted")
                do {
                    self.audioRecorder = try AVAudioRecorder(url: self.audioFile!, settings: self.recordSettings)
                    self.audioRecorder.record()
                } catch {
                    print("Error starting record = \(error)")
                }
            }
        }
    }
    
    func stopRecorder() {
        self.audioRecorder.stop()
        self.audioRecorder = nil
    }
    
    func setupAudioFile(name: String) -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        var url = paths[0]
        url = url.appendingPathComponent(name)
        print("audio file path = \(url)")
        return url
    }
    
    func startPlayer() {
        // start a player that reads a chunk from a file then deletes up to that point
        DispatchQueue.global().async {
            do {
            let audioOutFileHanle = try FileHandle(forReadingFrom: self.audioFile!)
            print("opened the audio file")
            let player = AVAudioPlayer()
            } catch {
                print("Error: \(error)")
            }
            self.readSamples(inFile: self.audioFile!, samplesToRead: 1000)
        }
    }
    
    // block until there is enough data in the file to read the requested number of 16 bit PCM samples
    func readSamples(inFile: URL, samplesToRead: UInt) {
        do {
            let inFileHandle = try FileHandle(forReadingFrom: inFile)
            let currentPosition = inFileHandle.offsetInFile
            let bytesToRead = samplesToRead * 2
            let requiredLength = currentPosition + UInt64(bytesToRead)
            let filePath = audioFile!.path
            do {
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: filePath)
                let lengthNow = fileAttributes[FileAttributeKey.size] as! UInt64
                print("file length = \(lengthNow)")
                if lengthNow < requiredLength {
                    sleep(1)
                } else {
                    // there is enough data there for us to read and play
                    let data = inFileHandle.readData(ofLength: Int(requiredLength))
                    
                }
            } catch {
                print("Error checking file size: \(error)")
                return
            }
        } catch {
            print("Error opening file for reading: \(error)")
            return;
        }
    }
}
