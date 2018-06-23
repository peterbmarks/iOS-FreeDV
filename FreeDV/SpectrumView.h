// AudioSpectrum: A sample app using Audio Unit and vDSP
// By Keijiro Takahashi, 2013, 2014
// https://github.com/keijiro/AudioSpectrum

#import <UIKit/UIKit.h>
#import "SpectrumAnalyzer.h"

@interface SpectrumView : UIView {

    SpectrumAnalyzer *_analyzer;
}

- (void)setSpectrumAnalyzer:(SpectrumAnalyzer*)analyzer;

@end
