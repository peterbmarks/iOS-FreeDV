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
  let audioSources = ["one", "two", "three", "four", "five"]
  
  
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var audioPickerView: UIPickerView!
  
  func numberOfComponents(in pickerView: UIPickerView) -> Int {
    return 1
  }
  
  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    return 5
  }
  
  func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
    return audioSources[row]
  }
  
  @IBAction func onDoneButton(_ sender: Any) {
    self.dismiss(animated: true) {
      print("dismissed choose radio")
    }
  }
}
