//
//  FreeDvModeViewController.swift
//  FreeDV
//
//  Created by Peter Marks on 26/6/18.
//  Copyright © 2018 Peter Marks. All rights reserved.
//

import UIKit

class FreeDvModeViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    @IBOutlet weak var modePickerView: UIPickerView!
    
    let modes = ["1600","700","700B","700C","700D","2400A","2400B","800XA"]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if let previousModeName = UserDefaults.standard.string(forKey: Constants.Preferences.FreeDvMode.rawValue) {
            let deviceIndex = previouslyChosenModeIndex(modeName: previousModeName)
            modePickerView.selectRow(deviceIndex, inComponent: 0, animated: false)
        } else {
            let deviceIndex = previouslyChosenModeIndex(modeName: "700D")
            modePickerView.selectRow(deviceIndex, inComponent: 0, animated: false)
        }
    }
    
    func previouslyChosenModeIndex(modeName: String) -> Int {
        var index = 0
        for mode in self.modes {
            if mode == modeName {
                return index
            }
            index += 1
        }
        return 0
    }
    
    @IBAction func onDoneButton(_ sender: Any) {
        let chosenModeRow = modePickerView.selectedRow(inComponent: 0)
        let chosenMode = self.modes[chosenModeRow]
        // let chosenDeviceId = chosenDevice.
        print("setting chosen mode name = \(chosenMode)")
        UserDefaults.standard.set(chosenMode, forKey: Constants.Preferences.FreeDvMode.rawValue)
        UserDefaults.standard.synchronize()
        self.dismiss(animated: true, completion: nil)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension FreeDvModeViewController {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.modes.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        let mode = self.modes[row]
        return mode
    }
    
}
