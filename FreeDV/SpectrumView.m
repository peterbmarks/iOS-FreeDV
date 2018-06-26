// AudioSpectrum: A sample app using Audio Unit and vDSP
// By Keijiro Takahashi, 2013, 2014
// https://github.com/keijiro/AudioSpectrum
// Ported from macos
// In NSView 0,0 is in the lower left with positive values of Y going up.
// In UIView 0,0 is in the top left with positive values of Y going down.


#import "SpectrumView.h"
#import "SpectrumAnalyzer.h"


#pragma mark Local Functions

#define MIN_DB (-60.0f)

static float ConvertLogScale(float x)
{
    return -log10f(0.1f + x / (MIN_DB * 1.1f));
}


#pragma mark

@implementation SpectrumView

- (void)setSpectrumAnalyzer:(SpectrumAnalyzer*)analyzer {
    _analyzer = analyzer;
}

- (void)setRingBuffersArray:(NSArray<AudioRingBuffer *>*)ringBuffers {
    _ringBuffers = ringBuffers;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    // Refresh 60 times in a second.
    [NSTimer scheduledTimerWithTimeInterval:(1.0f / 60) target:self selector:@selector(refresh) userInfo:nil repeats:YES];
    
}

- (void)refresh
{
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)dirtyRect
{
	[super drawRect:dirtyRect];

    CGSize size = self.frame.size;
    
    // Clear the rect.
    [[UIColor whiteColor] setFill];
    UIRectFill(dirtyRect);
    
    // Update the spectrum.
    //AudioInputHandler *audioInput = AudioInputHandler.sharedInstance;
    [_analyzer processAudioInput:_ringBuffers sampleRate:48000.0 allChannels:YES];
    
    // Draw horizontal lines.
    {
        UIBezierPath *path = [UIBezierPath bezierPath];
        
        for (float lv = -3.0f; lv > MIN_DB; lv -= 3.0f) {
            float y = ConvertLogScale(lv) * size.height;
            [path moveToPoint:CGPointMake(0, size.height - y)];
            [path addLineToPoint:CGPointMake(size.width, size.height - y)];
        }
        
        [[UIColor colorWithWhite:0.5f alpha:1.0f] setStroke];
        path.lineWidth = 0.5f;
        [path stroke];
    }
    
    // Draw the input waveform graph.
    
    {
        NSUInteger waveformLength = _analyzer.pointNumber;
        float waveform[waveformLength];
        [_ringBuffers.firstObject copyTo:waveform length:waveformLength];
        
        UIBezierPath *path = [UIBezierPath bezierPath];
        float xScale = size.width / waveformLength;
        
        for (NSUInteger i = 0; i < waveformLength; i++) {
            float x = xScale * i;
            float y = (waveform[i] * 0.5f + 0.5f) * size.height;
            if (i == 0) {
                [path moveToPoint:CGPointMake(x, y)];
            } else {
                [path addLineToPoint:CGPointMake(x, y)];
            }
        }
        
        [[UIColor colorWithWhite:0.5f alpha:1.0f] setStroke];
        path.lineWidth = 0.5f;
        [path stroke];
    }
    
    // Draw the level meter.
    /*
    {
        float zeroOffset = 1.5849e-13;
        float refLevel = 0.70710678118f; // 1/sqrt(2)

        NSColor *red = [NSColor colorWithHue:0.0f saturation:0.8f brightness:1.0f alpha:1.0f];
        NSColor *yellow = [NSColor colorWithHue:0.12f saturation:0.8f brightness:1.0f alpha:1.0f];
        NSColor *green = [NSColor colorWithHue:0.4f saturation:0.8f brightness:1.0f alpha:1.0f];
        
        int sampleCount = audioInput.sampleRate / 60; // 60 fps
        NSUInteger channels = audioInput.ringBuffers.count;
        
        for (NSUInteger i = 0; i < channels; i++)
        {
            float rms = [audioInput.ringBuffers[i] calculateRMS:sampleCount];
            float db = 20.0f * log10f(rms / refLevel + zeroOffset);
            float y = ConvertLogScale(db) * size.height;

            if (db >= 0.0f) {
                [red setFill];
            } else if (db > -3.0f) {
                [yellow setFill];
            } else {
                [green setFill];
            }
            
            NSRectFill(NSMakeRect((0.5f + i) * size.width / channels, 0, 12, y));
        }
    }
     */

    // Draw the octave band graph.
    /*
    {
        SpectrumDataRef spectrum = _analyzer.octaveBandSpectrumData;
        
        float barInterval = size.width / spectrum->length;
        float barWidth = 0.5f * barInterval;
        
        [[UIColor colorWithWhite:0.8f alpha:1.0f] setFill];
        
        for (NSUInteger i = 0; i < spectrum->length; i++) {
            float x = (0.5f + i)  * barInterval;
            float y = ConvertLogScale(spectrum->data[i]) * size.height;
            UIRectFill(CGRectMake(x - 0.5f * barWidth, 0, barWidth, y));
        }
    }
    */
    // Draw the spectrum graph.
    {
        SpectrumDataRef spectrum = _analyzer.rawSpectrumData;
        
        UIBezierPath *path = [UIBezierPath bezierPath];
        float xScale = size.width / log10f(spectrum->length - 1);

        for (NSUInteger i = 1; i < spectrum->length; i++) {
            float x = log10f(i) * xScale;
            float y = size.height - (ConvertLogScale(spectrum->data[i]) * size.height);
            if (i == 1) {
                [path moveToPoint:CGPointMake(x, y)];
            } else {
                [path addLineToPoint:CGPointMake(x, y)];
            }
        }
        
        [[UIColor blueColor] setStroke];
        path.lineWidth = 0.5f;
        [path stroke];
    }
}

@end
