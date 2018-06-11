//
//  FreeDVrx.c
//  FreeDV
//
//  Created by Peter Marks on 11/6/18.
//  Copyright © 2018 Peter Marks. All rights reserved.
//
//  C client for the FreeDV Api
//  This in turn gets called from Swift

#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>
#include <stdio.h>

#include "freedv_api.h"
#include "modem_stats.h"

#include "codec2.h"

#include "FreeDVrx.h"

struct my_callback_state {
    FILE *ftxt;
};

void my_put_next_rx_char(void *callback_state, char c) {
    struct my_callback_state* pstate = (struct my_callback_state*)callback_state;
    if (pstate->ftxt != NULL) {
        fprintf(pstate->ftxt, "text msg: %c\n", c);
    }
}

void my_put_next_rx_proto(void *callback_state,char *proto_bits){
    struct my_callback_state* pstate = (struct my_callback_state*)callback_state;
    if (pstate->ftxt != NULL) {
        fprintf(pstate->ftxt, "proto chars: %.*s\n",2, proto_bits);
    }
}

/* Called when a packet has been received */
void my_datarx(void *callback_state, unsigned char *packet, size_t size) {
    struct my_callback_state* pstate = (struct my_callback_state*)callback_state;
    if (pstate->ftxt != NULL) {
        size_t i;
        
        fprintf(pstate->ftxt, "data (%zd bytes): ", size);
        for (i = 0; i < size; i++) {
            fprintf(pstate->ftxt, "0x%02x ", packet[i]);
        }
        fprintf(pstate->ftxt, "\n");
    }
}

/* Called when a new packet can be send */
void my_datatx(void *callback_state, unsigned char *packet, size_t *size) {
    /* This should not happen while receiving.. */
    fprintf(stderr, "datarx callback called, this should not happen!\n");
    *size = 0;
}

void start_rx(const char *inFileName, const char *outFileName) {
    FILE                      *fin, *fout, *ftxt;
    struct freedv             *freedv;
    int                        nin, nout, frame = 0;
    struct my_callback_state   my_cb_state;
    struct MODEM_STATS         stats;
    int                        mode;
    int                        sync;
    float                      snr_est;
    float                      clock_offset;
    int                        use_codecrx, use_testframes, interleave_frames, verbose;
    struct CODEC2             *c2 = NULL;
    int                        i;
    
    use_codecrx = 0; use_testframes = 0; interleave_frames = 1; verbose = 0;
    mode = FREEDV_MODE_700D;
    
    if (mode == FREEDV_MODE_700D) {
        struct freedv_advanced adv;
        adv.interleave_frames = interleave_frames;
        freedv = freedv_open_advanced(mode, &adv);
    }
    else {
        freedv = freedv_open(mode);
    }
    assert(freedv != NULL);
    
    freedv_set_test_frames(freedv, use_testframes);
    freedv_set_verbose(freedv, verbose);
    
    freedv_set_snr_squelch_thresh(freedv, -100.0);
    freedv_set_squelch_en(freedv, 0);
    
    short speech_out[freedv_get_n_speech_samples(freedv)];
    short demod_in[freedv_get_n_max_modem_samples(freedv)];
    
    ftxt = stderr;
    assert(ftxt != NULL);
    my_cb_state.ftxt = ftxt;
    freedv_set_callback_txt(freedv, &my_put_next_rx_char, NULL, &my_cb_state);
    freedv_set_callback_protocol(freedv, &my_put_next_rx_proto, NULL, &my_cb_state);
    freedv_set_callback_data(freedv, my_datarx, my_datatx, &my_cb_state);
    
    fin = fopen(inFileName, "rb");
    assert(fin != NULL);
    fout = fopen(outFileName, "wb");
    assert(fout != NULL);
    
    /* Note we need to work out how many samples demod needs on each
     call (nin).  This is used to adjust for differences in the tx and rx
     sample clock frequencies.  Note also the number of output
     speech samples is time varying (nout). */
    
    nin = freedv_nin(freedv);
    while(fread(demod_in, sizeof(short), nin, fin) == nin) {
        frame++;
        
        if (use_codecrx == 0) {
            /* Use the freedv_api to do everything: speech decoding, demodulating */
            nout = freedv_rx(freedv, speech_out, demod_in);
        } else {
            int bits_per_codec_frame = codec2_bits_per_frame(c2);
            int bytes_per_codec_frame = (bits_per_codec_frame + 7) / 8;
            int codec_frames = freedv_get_n_codec_bits(freedv) / bits_per_codec_frame;
            int samples_per_frame = codec2_samples_per_frame(c2);
            unsigned char encoded[bytes_per_codec_frame * codec_frames];
            
            /* Use the freedv_api to demodulate only */
            nout = freedv_codecrx(freedv, encoded, demod_in);
            
            /* deccode the speech ourself (or send it to elsewhere, e.g. network) */
            if (nout) {
                unsigned char *enc_frame = encoded;
                short *speech_frame = speech_out;
                
                nout = 0;
                for (i = 0; i < codec_frames; i++) {
                    codec2_decode(c2, speech_frame, enc_frame);
                    enc_frame += bytes_per_codec_frame;
                    speech_frame += samples_per_frame;
                    nout += samples_per_frame;
                }
            }
        }
        
        nin = freedv_nin(freedv);
        
        fwrite(speech_out, sizeof(short), nout, fout);
        freedv_get_modem_stats(freedv, &sync, &snr_est);
        freedv_get_modem_extended_stats(freedv, &stats);
        int total_bit_errors = freedv_get_total_bit_errors(freedv);
        clock_offset = stats.clock_offset;
        
        /* log some side info to the txt file */
        
        if (ftxt != NULL) {
            fprintf(ftxt, "frame: %d  demod sync: %d  nin:%d demod snr: %3.2f dB  bit errors: %d clock_offset: %f\n",
                    frame, sync, nin, snr_est, total_bit_errors, clock_offset);
        }
        
        /* if this is in a pipeline, we probably don't want the usual
         buffering to occur */
        
        if (fout == stdout) fflush(stdout);
        if (fin == stdin) fflush(stdin);
    }
    
    if (freedv_get_test_frames(freedv)) {
        int Tbits = freedv_get_total_bits(freedv);
        int Terrs = freedv_get_total_bit_errors(freedv);
        fprintf(stderr, "BER......: %5.4f Tbits: %5d Terrs: %5d\n",  (float)Terrs/Tbits, Tbits, Terrs);
        if (mode == FREEDV_MODE_700D) {
            int Tbits_coded = freedv_get_total_bits_coded(freedv);
            int Terrs_coded = freedv_get_total_bit_errors_coded(freedv);
            fprintf(stderr, "Coded BER: %5.4f Tbits: %5d Terrs: %5d\n",
                    (float)Terrs_coded/Tbits_coded, Tbits_coded, Terrs_coded);
        }
    }
    
    freedv_close(freedv);
    fclose(fin);
    fclose(fout);
}

