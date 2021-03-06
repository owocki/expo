/**
 * Copyright (c) 2015-present, Horcrux.
 * All rights reserved.
 *
 * This source code is licensed under the MIT-style license found in the
 * LICENSE file in the root directory of this source tree.
 */


#import "ABI20_0_0RNSVGTSpan.h"
#import "ABI20_0_0RNSVGBezierTransformer.h"
#import "ABI20_0_0RNSVGText.h"
#import "ABI20_0_0RNSVGTextPath.h"

@implementation ABI20_0_0RNSVGTSpan
{
    ABI20_0_0RNSVGBezierTransformer *_bezierTransformer;
    CGPathRef _cache;
}

- (void)setContent:(NSString *)content
{
    if (content == _content) {
        return;
    }
    [self invalidate];
    _content = content;
}

- (void)renderLayerTo:(CGContextRef)context
{
    if (self.content) {
        [self renderPathTo:context];
    } else {
        [self clip:context];
        [self renderGroupTo:context];
    }
}

- (void)releaseCachedPath
{
    CGPathRelease(_cache);
    _cache = nil;
}

- (void)dealloc
{
    CGPathRelease(_cache);
}

- (CGPathRef)getPath:(CGContextRef)context
{
    if (_cache) {
        return _cache;
    }
    
    NSString *text = self.content;
    if (!text) {
        return [self getGroupPath:context];
    }
    
    [self setupTextPath:context];
    
    CGMutablePathRef path = CGPathCreateMutable();
    
    // append spacing
    text = [text stringByAppendingString:@" "];
    
    [self pushGlyphContext];
    CTFontRef font = [self getFontFromContext];
    
    // Create a dictionary for this font
    CFDictionaryRef attributes = (__bridge CFDictionaryRef)@{
                                                             (NSString *)kCTFontAttributeName: (__bridge id)font,
                                                             (NSString *)kCTForegroundColorFromContextAttributeName: @YES
                                                             };

    CFStringRef string = (__bridge CFStringRef)text;
    CFAttributedStringRef attrString = CFAttributedStringCreate(kCFAllocatorDefault, string, attributes);
    CTLineRef line = CTLineCreateWithAttributedString(attrString);
    
    CGMutablePathRef linePath = [self getLinePath:line];
    CGAffineTransform offset = CGAffineTransformMakeTranslation(0, _bezierTransformer ? 0 : CTFontGetSize(font) * 1.1);
    CGPathAddPath(path, &offset, linePath);
    CGPathRelease(linePath);
    
    _cache = CGPathRetain(CFAutorelease(CGPathCreateCopy(path)));
    [self popGlyphContext];
    
    // clean up
    CFRelease(attrString);
    CFRelease(line);
    
    return (CGPathRef)CFAutorelease(path);
}

- (CGMutablePathRef)getLinePath:(CTLineRef)line
{
    CGMutablePathRef path = CGPathCreateMutable();
    CFArrayRef runs = CTLineGetGlyphRuns(line);
    for (CFIndex i = 0; i < CFArrayGetCount(runs); i++) {
        CTRunRef run = CFArrayGetValueAtIndex(CTLineGetGlyphRuns(line), i);
        
        CFIndex runGlyphCount = CTRunGetGlyphCount(run);
        CGPoint positions[runGlyphCount];
        CGGlyph glyphs[runGlyphCount];
        
        // Grab the glyphs, positions, and font
        CTRunGetPositions(run, CFRangeMake(0, 0), positions);
        CTRunGetGlyphs(run, CFRangeMake(0, 0), glyphs);
        CTFontRef runFont = CFDictionaryGetValue(CTRunGetAttributes(run), kCTFontAttributeName);
        
        CGPoint glyphPoint;
        
        for(CFIndex i = 0; i < runGlyphCount; i++) {
            CGPathRef letter = CTFontCreatePathForGlyph(runFont, glyphs[i], nil);
            
            glyphPoint = [self getGlyphPointFromContext:positions[i] glyphWidth:CGRectGetWidth(CGPathGetBoundingBox(letter))];
            
            CGAffineTransform textPathTransform = CGAffineTransformIdentity;
            CGAffineTransform transform;
            if (_bezierTransformer) {
                textPathTransform = [_bezierTransformer getTransformAtDistance:glyphPoint.x];
                if ([self textPathHasReachedEnd]) {
                    CGPathRelease(letter);
                    break;
                } else if (![self textPathHasReachedStart]) {
                    CGPathRelease(letter);
                    continue;
                }
                
                textPathTransform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0, glyphPoint.y), textPathTransform);
                transform = CGAffineTransformScale(textPathTransform, 1.0, -1.0);
            } else {
                transform = CGAffineTransformTranslate(CGAffineTransformMakeScale(1.0, -1.0), glyphPoint.x, -glyphPoint.y);
            }
            
            CGPathAddPath(path, &transform, letter);
            CGPathRelease(letter);
        }
    }
    
    
    return path;
}

- (void)setupTextPath:(CGContextRef)context
{
    __block ABI20_0_0RNSVGBezierTransformer *bezierTransformer;
    [self traverseTextSuperviews:^(__kindof ABI20_0_0RNSVGText *node) {
        if ([node class] == [ABI20_0_0RNSVGTextPath class]) {
            bezierTransformer = [(ABI20_0_0RNSVGTextPath*)node getBezierTransformer];
            return NO;
        }
        return YES;
    }];
    
    _bezierTransformer = bezierTransformer;
}

- (void)traverseTextSuperviews:(BOOL (^)(__kindof ABI20_0_0RNSVGText *node))block
{
    ABI20_0_0RNSVGText *targetView = self;
    BOOL result = block(self);
    
    while (targetView && [targetView class] != [ABI20_0_0RNSVGText class] && result) {
        if (![targetView isKindOfClass:[ABI20_0_0RNSVGText class]]) {
            //todo: throw exception here
            break;
        }
        
        targetView = (ABI20_0_0RNSVGText*)[targetView superview];
        result = block(targetView);
    }
}

- (BOOL)textPathHasReachedEnd
{
    return [_bezierTransformer hasReachedEnd];
}

- (BOOL)textPathHasReachedStart
{
    return [_bezierTransformer hasReachedStart];
}

@end
