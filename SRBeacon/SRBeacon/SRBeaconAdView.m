//
//  SRBeaconAdView.m
//  Pods
//
//  Created by lifeng on 2/6/14.
//
//

#import "SRBeaconAdView.h"
#import "UIImageView+AFNetworking.h"

@interface SRBeaconAdView()
{
    
    UIScrollView    *scrollView;
}

@property (nonatomic, strong) NSURL *imageURL;
@property (nonatomic, strong) UIImageView *imageView;
@end

@implementation SRBeaconAdView

- (instancetype)initWithURL:(NSURL *)imageURL {
    
    if (( self = [super initWithFrame:[[UIScreen mainScreen] bounds]] )) {
        
        self.imageURL = imageURL;
        
        CGRect bounds = self.bounds;
        self.backgroundColor = [UIColor darkGrayColor];
        
        scrollView = [[UIScrollView alloc] initWithFrame:bounds];
        scrollView.delegate = self;
        scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        scrollView.maximumZoomScale = 1;
        scrollView.minimumZoomScale = 1;
        scrollView.zoomScale = 1;
        [self addSubview:scrollView];
        
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [closeButton setTitle:@"Close" forState:UIControlStateNormal];
        [closeButton setFrame:CGRectMake(bounds.size.width - 100, 20, 80, 40)];
        [closeButton addTarget:self action:@selector(onDismiss:) forControlEvents:UIControlEventTouchUpInside];
        [closeButton setAutoresizingMask:UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin];
        [self addSubview:closeButton];
        
        self.imageView = [[UIImageView alloc] initWithFrame:bounds];
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [scrollView addSubview:self.imageView];
        
        [self layoutImageView];
    }
    
    return self;
}

- (void)presentInView:(UIView *)container
{
    self.frame = CGRectMake(0, 0, container.frame.size.width, container.frame.size.height);
    [self layoutImageView];
    
    [container addSubview:self];
    
    self.alpha = 0;
    [UIView beginAnimations:Nil context:nil];
    [UIView setAnimationDuration:.35];
    self.alpha = 1;
    [UIView commitAnimations];
    
    
    __weak typeof (self) weakSelf = self;
    [self.imageView setImageWithURLRequest:[[NSURLRequest alloc] initWithURL:self.imageURL]
                     placeholderImage:nil
                              success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
                                  
                                  if (!weakSelf)
                                      return;
                                  
                                  weakSelf.imageView.image = image;
                                  [weakSelf layoutImageView];
                                  
                              }
                              failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
                                  
                                  if (!weakSelf)
                                      return;
                                  
                                  weakSelf.imageView.image = nil;
                                  [weakSelf layoutImageView];
                              }];
}

- (void)removeFromSuperview
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super removeFromSuperview];
}

- (void)show
{
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    
    [self setProperRotation:NO];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(setProperRotation)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
    
    [keyWindow addSubview:self];
    
    self.alpha = 0;
    [UIView beginAnimations:Nil context:nil];
    [UIView setAnimationDuration:.35];
    self.alpha = 1;
    [UIView commitAnimations];
    
    
    __weak typeof (self) weakSelf = self;
    [self.imageView setImageWithURLRequest:[[NSURLRequest alloc] initWithURL:self.imageURL]
                          placeholderImage:nil
                                   success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
                                       
                                       if (!weakSelf)
                                           return;
                                       
                                       weakSelf.imageView.image = image;
                                       [weakSelf layoutImageView];
                                       
                                   }
                                   failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
                                       
                                       if (!weakSelf)
                                           return;
                                       
                                       weakSelf.imageView.image = nil;
                                       [weakSelf layoutImageView];
                                   }];
}



#pragma mark - Privates

- (void)onDismiss:(id)sender
{
    [UIView animateWithDuration:.35
                     animations:^{
                         self.alpha = 0;
                     }
                     completion:^(BOOL finished) {
                         [self removeFromSuperview];
                     }];
}

- (void)layoutImageView
{
    
    if ([self.imageView image]) {
        
        CGFloat zoomScale = scrollView.zoomScale / scrollView.minimumZoomScale;
        scrollView.zoomScale = 1;
        
        CGSize imageSz = [self.imageView.image size];
        CGSize frameSz = [scrollView frame].size;
        CGFloat scale = (imageSz.width > imageSz.height) ? (imageSz.width / frameSz.width) : (imageSz.height / frameSz.height);
        
        if (scale > 1)
        {
            self.imageView.frame = CGRectMake(0, 0, frameSz.width * scale, frameSz.height * scale);
            
            scrollView.maximumZoomScale = 1;
            scrollView.minimumZoomScale = 1 / scale;
        }
        else
        {
            self.imageView.frame = CGRectMake(0, 0, frameSz.width * scale, frameSz.height * scale);
            self.imageView.center = CGPointMake(frameSz.width * 0.5, frameSz.height * 0.5);
            
            scrollView.maximumZoomScale = 1;
            scrollView.minimumZoomScale = 1;
        }
        
        scrollView.zoomScale = scrollView.minimumZoomScale * zoomScale;
    }
    else
    {
        CGSize frameSz = [scrollView frame].size;
        self.imageView.frame = CGRectMake(0, 0, frameSz.width, frameSz.height);
        
        scrollView.maximumZoomScale = 1;
        scrollView.minimumZoomScale = 1;
        scrollView.zoomScale = 1;
    }
}

- (CGSize)sizeForOrientation:(UIInterfaceOrientation)orientation
{
    CGSize size = [[[UIApplication sharedApplication] keyWindow] bounds].size;
    
    if (orientation == UIDeviceOrientationLandscapeLeft ||
        orientation == UIDeviceOrientationLandscapeRight)
		return CGSizeMake(size.height, size.width);
    
    return size;
}

- (void)setProperRotation
{
	[self setProperRotation:YES];
}

- (void)setProperRotation:(BOOL)animated
{
    
	UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
	UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    
	CGAffineTransform transform = self.transform;
    
    self.transform = CGAffineTransformIdentity;
    CGSize size = [self sizeForOrientation:orientation];
    
    CGRect frame = CGRectMake(round(keyWindow.bounds.size.width / 2 - size.width / 2),
                              round(keyWindow.bounds.size.height / 2 - size.height / 2),
                              size.width,
                              size.height);
    
    self.frame = frame;
    [self layoutImageView];
    
    self.transform = transform;
    if (animated)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.3];
	}
	
	if (orientation == UIDeviceOrientationPortraitUpsideDown)
		self.transform = CGAffineTransformRotate(CGAffineTransformIdentity, M_PI);
	else if (orientation == UIDeviceOrientationLandscapeLeft)
		self.transform = CGAffineTransformRotate(CGAffineTransformIdentity, M_PI_2);
	
	else if (orientation == UIDeviceOrientationLandscapeRight)
		self.transform = CGAffineTransformRotate(CGAffineTransformIdentity, -M_PI_2);
    else
        self.transform = CGAffineTransformIdentity;
	
	if (animated)
		[UIView commitAnimations];
}

#pragma mark - Scroll View

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.imageView;
}

@end
