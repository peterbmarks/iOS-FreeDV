// AudioSpectrum: A sample app using Audio Unit and vDSP
// By Keijiro Takahashi, 2013, 2014
// https://github.com/keijiro/AudioSpectrum

#import <UIKit/UIKit.h>
#import "SpectrumAnalyzer.h"
#import "AudioRingBuffer.h"

@interface SpectrumView : UIView {

    SpectrumAnalyzer *_analyzer;
    NSArray<AudioRingBuffer *>* _ringBuffers;
}

- (void)setSpectrumAnalyzer:(SpectrumAnalyzer*)analyzer;
- (void)setRingBuffersArray:(NSArray<AudioRingBuffer *>*)ringBuffers;

@end
