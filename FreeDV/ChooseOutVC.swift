//
//  ChooseOutVC.swift
//  FreeDV
//
//  Created by Peter Marks on 4/6/18.
//  Copyright © 2018 Peter Marks. All rights reserved.
//
//  View for choosing which audio output device

import UIKit
import AVFoundation

var player: AVAudioPlayer?

class ChooseOutVC: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
  var audioSession: AVAudioSession!
  
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var audioPickerView: UIPickerView!
  @IBOutlet weak var testAudioButton: UIButton!
  
  override func viewDidLoad() {
    audioSession = AVAudioSession.sharedInstance()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    titleLabel.text = "Choose output to radio"
    listOutputs()
  }

  @IBAction func onDoneButton(_ sender: Any) {
    self.dismiss(animated: true) {
      print("dismissed choose radio")
    }
  }
  
  @IBAction func onTestAudioButton(_ sender: Any) {
    print("test audio")
    // test calling a c function
    let hello = String(cString: say_hello())
    print("from c I got \(String(describing: hello))")
    playTestSound()
  }
  
  func listOutputs() {
    
    let currentRoute = audioSession.currentRoute
    for port in currentRoute.outputs {
      let description = port.portName
      print("portName = \(description)")
    }
  }
  
  // Thanks: https://stackoverflow.com/questions/32036146/how-to-play-a-sound-using-swift
  func playTestSound() {
    guard let url = Bundle.main.url(forResource: "tone1s440", withExtension: "aif") else { return }
    
    do {
      /*
       try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
       try AVAudioSession.sharedInstance().setActive(true)
       */
      
      /* The following line is required for the player to work on iOS 11. Change the file type accordingly*/
      player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.aiff.rawValue)
      
      /* iOS 10 and earlier require the following line:
       player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileTypeMPEGLayer3) */
      
      guard let player = player else { return }
      
      player.play()
      
    } catch let error {
      print(error.localizedDescription)
    }
  }
}

// Audio device picker delegate methods
extension ChooseOutVC {
  func numberOfComponents(in pickerView: UIPickerView) -> Int {
    return 1
  }
  
  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    if let outputDataSources = self.audioSession!.outputDataSources {
      return outputDataSources.count
    }
    return 0
  }
  
  func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
    let output = self.audioSession!.outputDataSources![row]
    return output.dataSourceName
  }
  
}
