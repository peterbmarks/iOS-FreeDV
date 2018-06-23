// AudioSpectrum: A sample app using Audio Unit and vDSP
// By Keijiro Takahashi, 2013, 2014
// https://github.com/keijiro/AudioSpectrum

#import <Foundation/Foundation.h>

@interface AudioRingBuffer : NSObject
{
@private
    float *_samples;
    NSUInteger _offset;
}

- (void)copyTo:(float *)destination length:(NSUInteger)length;
- (void)addTo:(float *)destination length:(NSUInteger)length;
- (void)splitEvenTo:(float *)even oddTo:(float *)odd totalLength:(NSUInteger)length;
- (void)vectorAverageWith:(float *)destination index:(NSUInteger)index length:(NSUInteger)length;
- (float)calculateRMS:(NSUInteger)length;
- (void)pushSamples:(float *)source count:(NSUInteger)count;

@end
