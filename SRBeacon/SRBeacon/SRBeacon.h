//
//  SRBeacon.h
//  Pods
//
//  Created by cuterabbit on 2/5/14.
//
//

#import <CoreLocation/CoreLocation.h>
#import "SRConstants.h"

/**
 SRBeacon is model object to represent iBeacon object in this system
 */
@interface SRBeacon : NSObject<NSCoding>

/// CLBeacon associated with this beacon
@property (nonatomic, strong) CLBeacon *beacon;

/// action SRBeacon should take against this beacon
@property (nonatomic, assign) SRAction action;

/// question SRBeacon should use for notification message against this beacon
@property (nonatomic, strong) NSString *question;

/// resource (this might be simple text or URL for image or video) SRBeacon should use against this beacon in users response
@property (nonatomic, strong) NSString *resource;

/// repeat
@property (nonatomic, assign) BOOL repeat;

/// repeat_interval
@property (nonatomic, assign) int repeatInterval;

/// last date this beacon is monitored
@property (nonatomic) NSDate *moniteredDate;

/// boundary RSSI value to be identified as a detected beacon in the system
@property (nonatomic) NSInteger limitOfRSSI;

/// UUID, received from the '/motes/discover' POST request
@property (nonatomic, strong) NSString *uuid;

/**
 init with CLBeacon
 @param beacon: CLBeacon to be used in order to initialize this beacon
 @return returns new SRBeacon
 */
- (instancetype)initWithCLBeacon:(CLBeacon *)beacon;

/**
 check if this beacon is one for specific CLBeacon
 @param beacon: CLBeacon
 @return returns YES if same
 */
- (BOOL)isEqualToCLBeacon:(CLBeacon *)beacon;

/**
 indicate if this beacon is can be detected by minimum RSSI in this system
 @return returns YES if this beacon is can be detected
 */
- (BOOL)canBeRanged;

@end
