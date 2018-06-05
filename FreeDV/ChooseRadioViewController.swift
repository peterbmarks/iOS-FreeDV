//
//  ChooseRadioViewController.swift
//  FreeDV
//
//  Created by Peter Marks on 4/6/18.
//  Copyright © 2018 Peter Marks. All rights reserved.
//
//  View for choosing which audio device for connection to radio

import UIKit
import AVFoundation

class ChooseRadioViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
  // this gets set by the previous view controller to tell us if we're
  // choosing inputs or outputs
  var outputMode = false
  
  var audioSession: AVAudioSession!
  
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var audioPickerView: UIPickerView!
    @IBOutlet weak var testAudioButton: UIButton!
    
  override func viewDidLoad() {
    audioSession = AVAudioSession.sharedInstance()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    if outputMode {
      titleLabel.text = "Choose output to radio"
    } else {
      titleLabel.text = "Choose input from radio"
    }
  }
  func numberOfComponents(in pickerView: UIPickerView) -> Int {
    return 1
  }
    
    @IBAction func onDoneButton(_ sender: Any) {
        self.dismiss(animated: true) {
            print("dismissed choose radio")
        }
    }
    
    @IBAction func onTestAudioButton(_ sender: Any) {
        print("test audio")
    }
}

// Audio device picker delegate methods
extension ChooseRadioViewController {
  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    if outputMode {
      // FIXME: get outputs
      return self.audioSession!.availableInputs!.count
    }
    return self.audioSession!.availableInputs!.count
  }
  
  func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
    let input = self.audioSession!.availableInputs![row]
    return input.portName
  }
  
}
