//
//  MTIImageView.m
//  Pods
//
//  Created by Yu Ao on 09/10/2017.
//

#if __has_include(<UIKit/UIKit.h>)

#import "MTIImageView.h"
#import "MTIContext+Rendering.h"
#import "MTIImage.h"
#import "MTIPrint.h"

@interface MTIImageView ()

@property (nonatomic,weak) MTKView *renderView;

@end

@implementation MTIImageView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupImageView];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self setupImageView];
    }
    return self;
}

- (void)setupImageView {
    if (@available(iOS 11.0, *)) {
        self.accessibilityIgnoresInvertColors = YES;
    }
    
    _resizingMode = MTIDrawableRenderingResizingModeAspect;
    
    NSError *error;
    _context = [[MTIContext alloc] initWithDevice:MTLCreateSystemDefaultDevice() error:&error];
    if (error) {
        NSLog(@"%@: Failed to create MTIContext - %@",self,error);
    }
    MTKView *renderView = [[MTKView alloc] initWithFrame:self.bounds device:_context.device];
    renderView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    renderView.delegate = self;
    [self addSubview:renderView];
    _renderView = renderView;
    
    _renderView.paused = YES;
    _renderView.enableSetNeedsDisplay = YES;
    _drawsImmediately = NO;
    
    self.opaque = YES;
}

- (void)setDrawsImmediately:(BOOL)drawsImmediately {
    _drawsImmediately = drawsImmediately;
    if (drawsImmediately) {
        _renderView.paused = YES;
        _renderView.enableSetNeedsDisplay = NO;
    } else {
        _renderView.paused = YES;
        _renderView.enableSetNeedsDisplay = YES;
    }
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) {
        _renderView.contentScaleFactor = self.window.screen.nativeScale;
    }
}

- (void)setContext:(MTIContext *)context {
    _context = context;
    _renderView.device = context.device;
}

- (void)setOpaque:(BOOL)opaque {
    BOOL oldOpaque = [super isOpaque];
    [super setOpaque:opaque];
    _renderView.opaque = opaque;
    _renderView.layer.opaque = opaque;
    if (oldOpaque != opaque) {
        [self setNeedsRedraw];
    }
}

- (void)setHidden:(BOOL)hidden {
    BOOL oldHidden = [super isHidden];
    [super setHidden:hidden];
    if (oldHidden) {
        [self setNeedsRedraw];
    }
}

- (void)setAlpha:(CGFloat)alpha {
    CGFloat oldAlpha = [super alpha];
    [super setAlpha:alpha];
    if (oldAlpha <= 0) {
        [self setNeedsRedraw];
    }
}

- (void)setColorPixelFormat:(MTLPixelFormat)colorPixelFormat {
    MTLPixelFormat oldColorPixelFormat = _renderView.colorPixelFormat;
    _renderView.colorPixelFormat = colorPixelFormat;
    if (oldColorPixelFormat != colorPixelFormat) {
        [self setNeedsRedraw];
    }
}

- (MTLPixelFormat)colorPixelFormat {
    return _renderView.colorPixelFormat;
}

- (void)setClearColor:(MTLClearColor)clearColor {
    MTLClearColor oldClearColor = _renderView.clearColor;
    _renderView.clearColor = clearColor;
    if (oldClearColor.red != clearColor.red ||
        oldClearColor.green != clearColor.green ||
        oldClearColor.blue != clearColor.blue ||
        oldClearColor.alpha != clearColor.alpha) {
        [self setNeedsRedraw];
    }
}

- (MTLClearColor)clearColor {
    return _renderView.clearColor;
}

- (void)updateContentScaleFactor {
    if (_renderView.frame.size.width > 0 && _renderView.frame.size.height > 0 && _image && _image.size.width > 0 && _image.size.height > 0 && self.window.screen != nil) {
        CGSize imageSize = _image.size;
        CGFloat widthScale = imageSize.width/_renderView.bounds.size.width;
        CGFloat heightScale = imageSize.height/_renderView.bounds.size.height;
        CGFloat nativeScale = self.window.screen.nativeScale;
        CGFloat scale = MIN(MAX(widthScale,heightScale),nativeScale);
        if (ABS(_renderView.contentScaleFactor - scale) > 0.00001) {
            _renderView.contentScaleFactor = scale;
        }
    }
}

- (void)setImage:(MTIImage *)image {
    NSAssert(NSThread.isMainThread, @"-[MTIImageView setImage:] can only be called on main thread.");
    if (_image != image) {
        _image = image;
        [self updateContentScaleFactor];
        [self setNeedsRedraw];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateContentScaleFactor];
    [self setNeedsRedraw];
}

- (void)setNeedsRedraw {
    if (_drawsImmediately) {
        [_renderView draw];
    } else {
        [_renderView setNeedsDisplay];
    }
}

#pragma mark - MTKViewDelegate

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    
}

- (void)drawInMTKView:(MTKView *)view {
    @autoreleasepool {
        if (!self.isHidden && self.alpha > 0) {
            MTIImage *imageToRender = _image;
            if (!imageToRender) {
                imageToRender = [MTIImage transparentImage];
            }
            NSAssert(_context != nil, @"Context is nil.");
            MTIDrawableRenderingRequest *request = [[MTIDrawableRenderingRequest alloc] init];
            request.drawableProvider = _renderView;
            request.resizingMode = _resizingMode;
            NSError *error;
            [_context renderImage:imageToRender toDrawableWithRequest:request error:&error];
            if (error) {
                MTIPrint(@"%@: Failed to render image %@ - %@",self,imageToRender,error);
            }
        }
    }
}

@end

#endif
