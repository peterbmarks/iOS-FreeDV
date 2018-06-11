//
//  FreeDVApi.swift
//  FreeDV
//
//  Created by Peter Marks on 10/6/18.
//  Copyright © 2018 Peter Marks. All rights reserved.
//
//  A simple swift wrapper for the FreeDV API

import Foundation
import UIKit

class FreeDVApi {
    init() {
        print("in FreeDVApi init()")
    }
    
    func startDecodeFromFileToFile() {
        let inFilePath = Bundle.main.path(forResource: "vk2tpm_004", ofType: "wav")!
        print("reading: \(inFilePath)")
        let documentsDirectory = getDocumentsDirectory()
        let outFilePath = documentsDirectory.appending("/decoded.bin")
        print("writing to: \(outFilePath)")
        start_rx(inFilePath, outFilePath)
    }
    
    func getDocumentsDirectory() -> String {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.path
    }
}
