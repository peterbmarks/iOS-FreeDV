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

// Functions to be called from FreeDVrx.c

// https://gist.github.com/HiImJulien/c79f07a8a619431b88ea33cca51de787
// Copy requestedSamples CShorts into the buffer and
// return the number of Ints we copied into the buffer
@_cdecl("getArrayOfAudioSamples")
public func getArrayOfAudioSamples(buffer: UnsafePointer<CShort>, requestedSamples: CShort) -> CInt {
    print("### c called getArrayOfAudioSamples")
    return 0
}

@_cdecl("documentsDirectoryPath")
public func documentsDirectoryPath() -> UnsafePointer<Int8> {
    let nsDocumentDirectory = FileManager.SearchPathDirectory.documentDirectory
    let nsUserDomainMask    = FileManager.SearchPathDomainMask.userDomainMask
    let paths               = NSSearchPathForDirectoriesInDomains(nsDocumentDirectory, nsUserDomainMask, true)
    let dirPath          = paths.first!
    let dirPathRepresentation = FileManager.default.fileSystemRepresentation(withPath: dirPath + "/out.raw")
    print("dirPathRepresentation = \(dirPathRepresentation)")
    NSLog("%s", dirPathRepresentation)
    return dirPathRepresentation
}

class FreeDVApi {
    init() {
        print("in FreeDVApi init()")
    }
    
    func startFreeDvRx() {
        start_rx()
    }
}

