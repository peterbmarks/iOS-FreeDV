//
//  ViewController.swift
//  FreeDV
//
//  Created by Peter Marks on 3/6/18.
//  Copyright © 2018 Peter Marks. All rights reserved.
//
// Thanks: https://www.hackingwithswift.com/example-code/media/how-to-record-audio-using-avaudiorecorder

import UIKit
import AVFoundation

class ViewController: UIViewController, AVAudioRecorderDelegate {

  @IBOutlet weak var toRadioButton: UIButton!
  @IBOutlet weak var fromRadioButton: UIButton!
  @IBOutlet weak var transmitSwitch: UISwitch!
  @IBOutlet weak var startSwitch: UISwitch!
  @IBOutlet weak var statusLabel: UILabel!
  @IBOutlet weak var audioLevelProgressView: UIProgressView!
  
  var recordingSession: AVAudioSession!
  var audioRecorder: AVAudioRecorder!
  
  override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
      recordingSession = AVAudioSession.sharedInstance()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

  // start receiving
  @IBAction func onStartSwitchChanged(_ sender: UISwitch) {
    print("Start switch changed")
    if sender.isOn == true {
      print("switch now on")
      do {
        try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
        try recordingSession.setActive(true)
        self.transmitSwitch.isEnabled = true
      } catch {
        // failed to record!
        print("Error starting audio session")
        statusLabel.text = "Error starting audio session"
        self.transmitSwitch.isEnabled = false
      }
    } else {
      print("recording stopped")
      self.transmitSwitch.isEnabled = false
    }
  }
  
  @IBAction func onToRadioButton(_ sender: UIButton) {
    print("Tapped the To radio audio button")
  }
  
  @IBAction func onFromRadioButton(_ sender: UIButton) {
    print("Tapped the From radio audio button")
  }
  
  @IBAction func transmitSwitchAction(_ sender: UISwitch) {
    print("Transmit switch changed")
    if sender.isOn == true {
      print("started transmitting")
      recordingSession.requestRecordPermission() { [unowned self] allowed in
          DispatchQueue.main.async {
            if allowed {
              self.startRecording()
            } else {
              // failed to record!
              self.statusLabel.text = "Needs permission to access microphone"
              self.transmitSwitch.isOn = false
            }
          }
        }
    }
  }
  
  func startRecording () {
    let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
    
    let settings = [
      AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
      AVSampleRateKey: 12000,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
    
    do {
      audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
      audioRecorder.delegate = self
      audioRecorder.record()
      
      //recordButton.setTitle("Tap to Stop", for: .normal)
    } catch {
      finishRecording(success: false)
    }
  }
  
  func finishRecording(success: Bool) {
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
  
  func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
  }
}

