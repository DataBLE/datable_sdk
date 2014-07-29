//
//  SRBeaconManager.h
//  Canabalt
//
//  Created by cuterabbit on 1/17/14.
//
//

#import <UIKit/UIKit.h>
#import "SRConstants.h"

@class SRBeaconAdView;

/**
 SRBeaconManager is daemon class to control all actions from the user,
 detection of nearby mote, request action info to the server against monitored beacon,
 getting action from the server, notify to user about monitoring of beacon, handle user action,
 perform action and so on..
 */
@interface SRBeaconManager : NSObject

/**
 creates a shared instance of beacon manager and returns
 @return returns created and initialized beacon manager object
 */
+ (instancetype)sharedInstance;

/**
 start beacons monitoring in the range, this starts monitoring 1 second later
 along user's gender, the action at detecting the beacon will be different
 @param gender: gender of user
 */
- (void)startForGender:(SRGender)gender;

/**
 handle action
 @param notification: local notification for sdk to handle
 this will include some informations such as beacon dientifier, proximity UUID/major/minor, gender,
 action, question and resource associated with beacon and action of that
 */
- (void)handleNotification:(UILocalNotification *)notification;

/**
 stop beacon monitoring, location updating.
 */
- (void)stop;


@end
