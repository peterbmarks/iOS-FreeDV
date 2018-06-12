//
//  FreeDVrx.h
//  FreeDV
//
//  Created by Peter Marks on 11/6/18.
//  Copyright © 2018 Peter Marks. All rights reserved.
//

#ifndef FreeDVrx_h
#define FreeDVrx_h

#include <stdio.h>

// c function to call from swift
void start_rx(const char *inFileName, const char *outFileName);

// swift function to call from c
int getArrayOfAudioSamples(short *demodInputBuffer, int inputSampleCount);

#endif /* FreeDVrx_h */
