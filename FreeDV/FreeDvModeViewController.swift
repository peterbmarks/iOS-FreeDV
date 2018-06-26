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
        // 700D default
        modePickerView.selectRow(4, inComponent: 0, animated: false)
    }
    

    @IBAction func onDoneButton(_ sender: Any) {
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
