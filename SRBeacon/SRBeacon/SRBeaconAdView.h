//
//  SRBeaconAdView.h
//  Pods
//
//  Created by lifeng on 2/6/14.
//
//

#import <UIKit/UIKit.h>

/**
 SRBeaconAdView is used custom ads view class to be used to show image
 This will be used when SDK should take action for image type of action
 */
@interface SRBeaconAdView : UIView<UIScrollViewDelegate>

- (instancetype) initWithURL:(NSURL *)imageURL;

/**
 show in a view (as a subview)
 */
- (void)presentInView:(UIView *)container;

/**
 show in a window
 */
- (void)show;
@end
