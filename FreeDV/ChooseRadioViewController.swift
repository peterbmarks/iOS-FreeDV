//
//  ChooseRadioViewController.swift
//  FreeDV
//
//  Created by Peter Marks on 4/6/18.
//  Copyright © 2018 Peter Marks. All rights reserved.
//

import UIKit
import AVFoundation

class ChooseRadioViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
  var audioSession: AVAudioSession!
  
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var audioPickerView: UIPickerView!
  
  override func viewDidLoad() {
    audioSession = AVAudioSession.sharedInstance()
  }
  
  func numberOfComponents(in pickerView: UIPickerView) -> Int {
    return 1
  }

  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    return self.audioSession!.availableInputs!.count
  }
  
  func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
    let input = self.audioSession!.availableInputs![row]
    return input.portName
  }
  
  @IBAction func onDoneButton(_ sender: Any) {
    self.dismiss(animated: true) {
      print("dismissed choose radio")
    }
  }
}
