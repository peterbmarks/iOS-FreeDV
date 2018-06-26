//
//  SettingsViewController.swift
//  FreeDV
//
//  Created by Peter Marks on 26/6/18.
//  Copyright © 2018 Peter Marks. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func onCloseButton(_ sender: Any) {
        self.dismiss(animated: true) {
            print("settings dismissed")
        }
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
