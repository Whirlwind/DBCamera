//
//  DBCameraSegueViewController.hViewController
//  CropImage
//
//  Created by Daniele Bogo on 19/04/14.
//  Copyright (c) 2014 Daniele Bogo. All rights reserved.
//

#import "DBCameraSegueViewController.h"
#import "DBCameraBaseCropViewController+Private.h"
#import "DBCameraCropView.h"
#import "UIImage+TintColor.h"

#ifndef DBCameraLocalizedStrings
#define DBCameraLocalizedStrings(key) \
NSLocalizedStringFromTable(key, @"DBCamera", nil)
#endif

#define buttonMargin 20.0f

@interface DBCameraSegueViewController () <UIActionSheetDelegate> {
    DBCameraCropView *_cropView;
    
    NSArray *_cropArray;
    CGRect _pFrame, _lFrame;
}

@property (nonatomic, assign) BOOL cropMode;
@property (nonatomic, strong) UIView *navigationBar, *bottomBar;
@property (nonatomic, strong) UIButton *useButton, *retakeButton, *cropButton;
@end

@implementation DBCameraSegueViewController
@synthesize forceQuadCrop = _forceQuadCrop;
@synthesize useCameraSegue = _useCameraSegue;
@synthesize tintColor = _tintColor;
@synthesize selectedTintColor = _selectedTintColor;

- (id) initWithImage:(UIImage *)image thumb:(UIImage *)thumb
{
    self = [super init];
    if (self) {
        // Custom initialization
        _cropArray = @[ @320, @213, @240, @192, @180 ];
        
        [self setSourceImage:image];
        [self setPreviewImage:thumb];
        [self setCropRect:(CGRect){ 0, 320 }];
        [self setMinimumScale:.2];
        [self setMaximumScale:10];
        [self createInterface];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self.view setUserInteractionEnabled:YES];
    [self.view setBackgroundColor:[UIColor blackColor]];
    [self.view addSubview:self.navigationBar];
    [self.view addSubview:self.bottomBar];
    [self.view setClipsToBounds:YES];
    
    CGFloat cropX = ( CGRectGetWidth( self.frameView.frame) - 320 ) * .5;
    _pFrame = (CGRect){ cropX, ( CGRectGetHeight( self.frameView.frame) - 360 ) * .5, 320, 320 };
    _lFrame = (CGRect){ cropX, ( CGRectGetHeight( self.frameView.frame) - 240) * .5, 320, 240 };
    
    [self setCropRect:self.previewImage.size.width > self.previewImage.size.height ? _lFrame : _pFrame];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ( _forceQuadCrop ) {
        [self setCropMode:YES];
        [self setCropRect:_pFrame];
        [self reset:YES];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) cropModeAction:(UIButton *)button
{
    [button setSelected:!button.isSelected];
    [self setCropMode:button.isSelected];
    [self setCropRect:button.isSelected ? _pFrame : _lFrame];
    [self reset:YES];
}

- (void) openActionsheet:(UIButton *)button
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:DBCameraLocalizedStrings(@"general.button.cancel") destructiveButtonTitle:nil otherButtonTitles:DBCameraLocalizedStrings(@"cropmode.square"), @"3:2", @"4:3", @"5:3", @"16:9", nil];
    [actionSheet showInView:self.view];
}

- (void) createInterface
{
    CGFloat viewHeight = CGRectGetHeight([[UIScreen mainScreen] bounds]) - 64 - 50;
    _cropView = [[DBCameraCropView alloc] initWithFrame:(CGRect){ 0, 64, 320, viewHeight }];
    [_cropView setHidden:YES];
    
    [self setFrameView:_cropView];
}

- (void) retakeImage
{
    [self.navigationController popViewControllerAnimated:YES];
    [self setSourceImage:nil];
    [self setPreviewImage:nil];
}

- (void) saveImage
{
    if ( [_delegate respondsToSelector:@selector(camera:didFinishWithImage:withMetadata:)] ) {
        if ( _cropMode )
            [self cropImage];
        else{
            UIImage *transform = [[self setFilter:self.selectedFilterIndex.row] imageByFilteringImage:self.sourceImage];
            [_delegate camera:self didFinishWithImage:transform withMetadata:self.capturedImageMetadata];
        }
    }
}

- (void) cropImage
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CGImageRef resultRef = [self newTransformedImage:self.imageView.transform
                                             sourceImage:self.sourceImage.CGImage
                                              sourceSize:self.sourceImage.size
                                       sourceOrientation:self.sourceImage.imageOrientation
                                             outputWidth:self.outputWidth ? self.outputWidth : self.sourceImage.size.width
                                                cropRect:self.cropRect
                                           imageViewSize:self.imageView.bounds.size];
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImage *transform =  [UIImage imageWithCGImage:resultRef scale:1.0 orientation:UIImageOrientationUp];
            CGImageRelease(resultRef);
            transform = [[self setFilter:self.selectedFilterIndex.row] imageByFilteringImage:transform];
            [_delegate camera:self didFinishWithImage:transform withMetadata:self.capturedImageMetadata];
        });
    });
}

- (void) setCropMode:(BOOL)cropMode
{
    _cropMode = cropMode;
    [self.frameView setHidden:!_cropMode];
    [self.bottomBar setHidden:!_cropMode];
    [self.filtersView setHidden:_cropMode];
}

- (UIView *) navigationBar
{
    if ( !_navigationBar ) {
        _navigationBar = [[UIView alloc] initWithFrame:(CGRect){ 0, 0, 320, 64 }];
        [_navigationBar setBackgroundColor:[UIColor blackColor]];
        [_navigationBar setUserInteractionEnabled:YES];
        [_navigationBar addSubview:self.useButton];
        [_navigationBar addSubview:self.retakeButton];
        if ( !_forceQuadCrop )
            [_navigationBar addSubview:self.cropButton];
    }
    
    return _navigationBar;
}

- (UIView *) bottomBar
{
    if ( !_bottomBar ) {
        _bottomBar = [[UIView alloc] initWithFrame:(CGRect){ 0, CGRectGetHeight([[UIScreen mainScreen] bounds]) - 40, 320, 40 }];
        [_bottomBar setBackgroundColor:[UIColor blackColor]];
        [_bottomBar setHidden:YES];
        
        UIButton *actionsheetButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [actionsheetButton setFrame:_bottomBar.bounds];
        [actionsheetButton setBackgroundColor:[UIColor clearColor]];
        [actionsheetButton setTitle:DBCameraLocalizedStrings(@"cropmode.title") forState:UIControlStateNormal];
        [actionsheetButton addTarget:self action:@selector(openActionsheet:) forControlEvents:UIControlEventTouchUpInside];
        [_bottomBar addSubview:actionsheetButton];
    }
    
    return _bottomBar;
}

- (UIButton *) useButton
{
    if ( !_useButton ) {
        _useButton = [self baseButton];
        [_useButton setTitle:[DBCameraLocalizedStrings(@"button.use") uppercaseString] forState:UIControlStateNormal];
        [_useButton.titleLabel sizeToFit];
        [_useButton sizeToFit];
        [_useButton setFrame:(CGRect){ CGRectGetWidth(self.view.frame) - (CGRectGetWidth(_useButton.frame) + buttonMargin), 0, CGRectGetWidth(_useButton.frame) + buttonMargin, 60 }];
        [_useButton addTarget:self action:@selector(saveImage) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _useButton;
}

- (UIButton *) retakeButton
{
    if ( !_retakeButton ) {
        _retakeButton = [self baseButton];
        [_retakeButton setTitle:[DBCameraLocalizedStrings(@"button.retake") uppercaseString] forState:UIControlStateNormal];
        [_retakeButton.titleLabel sizeToFit];
        [_retakeButton sizeToFit];
        [_retakeButton setFrame:(CGRect){ 0, 0, CGRectGetWidth(_retakeButton.frame) + buttonMargin, 60 }];
        [_retakeButton addTarget:self action:@selector(retakeImage) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _retakeButton;
}

- (UIButton *) cropButton
{
    if ( !_cropButton) {
        _cropButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_cropButton setBackgroundColor:[UIColor clearColor]];
        [_cropButton setImage:[[UIImage imageNamed:@"Crop"] tintImageWithColor:self.tintColor] forState:UIControlStateNormal];
        [_cropButton setImage:[[UIImage imageNamed:@"Crop"] tintImageWithColor:self.selectedTintColor] forState:UIControlStateSelected];
        [_cropButton setFrame:(CGRect){ CGRectGetMidX(self.view.bounds) - 15, 15, 30, 30 }];
        [_cropButton addTarget:self action:@selector(cropModeAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _cropButton;
}

- (UIButton *) baseButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setBackgroundColor:[UIColor clearColor]];
    [button setTitleColor:self.tintColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:12];
    
    return button;
}

- (BOOL) prefersStatusBarHidden
{
    return YES;
}

#pragma mark - UIActionSheetDelegate

- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ( buttonIndex != actionSheet.cancelButtonIndex ) {
        NSUInteger height = [_cropArray[buttonIndex] integerValue];
        CGFloat cropX = ( CGRectGetWidth( self.frameView.frame) - 320 ) * .5;
        CGRect cropRect = (CGRect){ cropX, ( CGRectGetHeight( self.frameView.frame) - (CGRectGetHeight(self.bottomBar.frame) + height) ) * .5, 320, height };
        
        [self setCropRect:cropRect];
        [self reset:YES];
    }
}

@end