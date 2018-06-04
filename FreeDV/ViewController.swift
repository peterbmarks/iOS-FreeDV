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

class ViewController: UIViewController {

  @IBOutlet weak var toRadioButton: UIButton!
  @IBOutlet weak var fromRadioButton: UIButton!
  @IBOutlet weak var transmitSwitch: UISwitch!
  @IBOutlet weak var startSwitch: UISwitch!
  @IBOutlet weak var statusLabel: UILabel!
  
  var recordingSession: AVAudioSession!
  
  override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
      recordingSession = AVAudioSession.sharedInstance()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

  @IBAction func onStartSwitchChanged(_ sender: UISwitch) {
    print("Start switch changed")
    if sender.isOn == true {
      print("switch now on")
      do {
        try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
        try recordingSession.setActive(true)
        recordingSession.requestRecordPermission() { [unowned self] allowed in
          DispatchQueue.main.async {
            if allowed {
              //self.loadRecordingUI()
            } else {
              // failed to record!
            }
          }
        }
      } catch {
        // failed to record!
        print("Error starting record")
        statusLabel.text = "Error starting record session"
      }
    } else {
      print("recording stopped")
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
  }
  
}

