//
//  ChooseInVC.swift
//  FreeDV
//
//  Created by Peter Marks on 4/6/18.
//  Copyright © 2018 Peter Marks. All rights reserved.
//
//  View for choosing which audio input device

import UIKit
import AVFoundation

class ChooseInVC: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
  var audioSession: AVAudioSession!
  
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var audioPickerView: UIPickerView!
  @IBOutlet weak var testAudioButton: UIButton!
    
  override func viewDidLoad() {
    audioSession = AVAudioSession.sharedInstance()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    titleLabel.text = "Choose input from radio"
    if let previousDeviceName = UserDefaults.standard.string(forKey: Constants.Preferences.FromRadioDevice.rawValue) {
      print("previously chosen Device name = \(String(describing: previousDeviceName))")
      let deviceIndex = previouslyChosenDeviceIndex(deviceName: previousDeviceName)
      audioPickerView.selectRow(deviceIndex, inComponent: 0, animated: false)
    }
    NotificationCenter.default.addObserver(self, selector: #selector(ChooseInVC.handleRouteChangedNotification(notification:)), name: .AVAudioSessionRouteChange, object: nil)
  }
  
  func previouslyChosenDeviceIndex(deviceName: String) -> Int {
    var index = 0
    for device in self.audioSession!.availableInputs! {
      if device.portName == deviceName {
        return index
      }
      index += 1
    }
    return 0
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
        print("audio device changed")
        DispatchQueue.main.async {
          self.audioPickerView.reloadComponent(0)
        }
      
      case .oldDeviceUnavailable:
        print("audio device changed")
        DispatchQueue.main.async {
          self.audioPickerView.reloadComponent(0)
      }
      default: ()
    }
  }
  
  func numberOfComponents(in pickerView: UIPickerView) -> Int {
    return 1
  }
    
    @IBAction func onDoneButton(_ sender: Any) {
      let chosenDeviceRow = audioPickerView.selectedRow(inComponent: 0)
      let chosenDevice = self.audioSession!.availableInputs![chosenDeviceRow]
      let chosenDeviceName = chosenDevice.portName
      print("chosen Device name = \(chosenDeviceName)")
      UserDefaults.standard.set(chosenDeviceName, forKey: Constants.Preferences.FromRadioDevice.rawValue)
      UserDefaults.standard.synchronize()
      self.dismiss(animated: true) {
          print("dismissed choose radio")
      }
    }
    
    @IBAction func onTestAudioButton(_ sender: Any) {
        print("test audio")
        let hello = String(cString: say_hello())
        print("from c I got \(String(describing: hello))")
    }
}

// Audio device picker delegate methods
extension ChooseInVC {
  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    return self.audioSession!.availableInputs!.count
  }
  
  func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
    let input = self.audioSession!.availableInputs![row]
    return input.portName
  }
  
}
