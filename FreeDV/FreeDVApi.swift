//
//  FreeDVApi.swift
//  FreeDV
//
//  Created by Peter Marks on 10/6/18.
//  Copyright © 2018 Peter Marks. All rights reserved.
//
//  A simple swift wrapper for the FreeDV API

import Foundation

class FreeDVApi {
    var use_codecrx = false
    var use_testframes = false
    var interleave_frames:Int32 = 1
    var verbose = false
    
    var mode:Int32 = -1
    
    // struct freedv defined in freedv_api_internal.h
    var freedv:OpaquePointer? = nil
    var adv:freedv_advanced = freedv_advanced()
    
    // porting freedv_rx.c here
    init() {
        mode = FREEDV_MODE_700D
        if mode == FREEDV_MODE_700D {
            adv.interleave_frames = interleave_frames
            freedv = freedv_open_advanced(mode, &adv)   // in freedv_api.c
        }
    }
}
