//
//  FreeDVApi.swift
//  FreeDV
//
//  Created by Peter Marks on 10/6/18.
//  Copyright © 2018 Peter Marks. All rights reserved.
//
//  A simple swift wrapper for the FreeDV API

import Foundation

struct my_callback_state {
    var ftxt:OpaquePointer? = nil
}

// https://stackoverflow.com/questions/40332398/using-a-c-api-function-in-swift-3-that-has-a-callback-function-pointer-as-an-arg
func my_put_next_rx_char(callback_state:OpaquePointer?, c:Character, user: UnsafeMutableRawPointer?) -> Void {
    print("text msg: \(c)");
}

class FreeDVApi {
    var use_codecrx = false
    var use_testframes:Int32 = 0
    var interleave_frames:Int32 = 1
    var verbose:Int32 = 0
    var mode:Int32 = -1
    var my_cb_state = my_callback_state()
    
    // struct freedv defined in freedv_api_internal.h
    var freedv:OpaquePointer? = nil
    var adv:freedv_advanced = freedv_advanced()
    
    // porting freedv_rx.c here
    init() {
        print("in FreeDVApi init()")
        mode = FREEDV_MODE_700D
        if mode == FREEDV_MODE_700D {
            adv.interleave_frames = interleave_frames
            freedv = freedv_open_advanced(mode, &adv)   // in freedv_api.c
        }
        freedv_set_test_frames(freedv, use_testframes);
        freedv_set_verbose(freedv, verbose);
        
        freedv_set_snr_squelch_thresh(freedv, -100.0);
        freedv_set_squelch_en(freedv, 0);
        
        let n_speech_samples = Int(freedv_get_n_speech_samples(freedv))
        // Make an array of the right size
        let speech_out = [Int16?](repeating: nil, count: n_speech_samples)
        
        let n_max_modem_samples = Int(freedv_get_n_max_modem_samples(freedv))
        let demod_in = [Int16?](repeating: nil, count: n_max_modem_samples)
        
        //freedv_set_callback_txt(freedv, rx:my_pu, <#T##tx: freedv_callback_tx!##freedv_callback_tx!##(UnsafeMutableRawPointer?) -> Int8#>, <#T##callback_state: UnsafeMutableRawPointer!##UnsafeMutableRawPointer!#>)
        // freedv_set_callback_txt(freedv, my_put_next_rx_char, nil, &my_cb_state);
    }
}
