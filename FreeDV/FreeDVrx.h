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
void rx_init(void);
void start_rx(void);    // this doesn't return until
void stop_rx(void);

// swift function to call from c
int getArrayOfAudioSamples(short *demodInputBuffer, int inputSampleCount);

extern struct FIFO *gAudioCaptureFifo;
extern struct FIFO *gAudioDecodedFifo;

#endif /* FreeDVrx_h */
