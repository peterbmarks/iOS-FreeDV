//
//  PeakLevelFilter.swift
//  FreeDV
//
//  Created by Peter Marks on 9/6/18.
//  Copyright © 2018 Peter Marks. All rights reserved.
//
//  Walk through the samples and get the largest value

import AudioToolbox


class PeakLevelFilter {
    func peakLevel(_ ioData: UnsafeMutablePointer<Float32>, numFrames: UInt32) -> Float32 {
        var peak: Float32 = 0.0
        for i in 0..<Int(numFrames) {
            let xCurr = ioData[i]
            if xCurr > peak {
                peak = xCurr
            }
        }
        return peak
    }
}
