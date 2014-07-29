//
//  SRBeaconManager.m
//  Canabalt
//
//  Created by cuterabbit on 1/17/14.
//
//

#import "SRBeaconManager.h"
#import <CoreLocation/CoreLocation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <AFNetworking.h>
#import "SRSessionManager.h"
#import "SRBeacon.h"
#import "SRBeaconAdView.h"
#import "Reachability.h"

typedef NS_ENUM(NSInteger, SRRequest)
{
    SRRequestBeaconList,
    SRRequestActionForBecon,
    SRRequestConfirmMote
};

NSString * const kMoteList     = @"/motes/app";
NSString * const kMotes        = @"/motes/discover";
NSString * const kMotesConfirm = @"/motes/confirm";

NSString * const kAppDataDirectory  = @"SRbeacon";
NSString * const kAppDataFileName   = @"beacons.plist";
NSString * const kAppData           = @"data";

NSString * const kApp           = @"app";
NSString * const kPlatform      = @"platform";
NSString * const kMote          = @"mote";
NSString * const kProximityUUID = @"uuid";
NSString * const kMajor         = @"major";
NSString * const kMinor         = @"minor";
NSString * const kGender        = @"gender";
NSString * const kAction        = @"action";
NSString * const kQuestion      = @"question";
NSString * const kResource      = @"resource";
NSString * const kUUID          = @"uuid";
NSString * const kMessage       = @"message";
NSString * const kMessageYES    = @"YES";
NSString * const kMessageNO     = @"NO";
NSString * const kRSSI          = @"rssi";
NSString * const kErrors        = @"errors";
NSString * const kRepeat        = @"repeat";
NSString * const kRepeatInterval = @"repeat_interval";
NSString * const kLatitude      = @"lat";
NSString * const kLongitude     = @"lon";
NSString * const kDistance      = @"distance";

NSString * const kActionText    = @"text";
NSString * const kActionImage   = @"image";
NSString * const kActionVideo   = @"video";
NSString * const kActionTVImage = @"tv-image";
NSString * const kActionTVVideo = @"tv-video";
double const baseDelayRequestTime = 2.0;

@interface SRAlertView:UIAlertView

@property (nonatomic, strong) id userInfo;
@end

@implementation SRAlertView

@end

@interface SRBeaconManager() <CLLocationManagerDelegate, UIAlertViewDelegate>

/// location manager
@property (nonatomic, strong) CLLocationManager *locationManager;

/// user's gender
@property (nonatomic, assign) SRGender gender;

/// app key
@property (nonatomic, strong) NSString *appKey;

/// current background task identifier
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTask;

/// ranged beacons manager has ranged since beginning state
@property (nonatomic, strong) NSMutableArray *rangedBeacons;

/// current location
@property (nonatomic, strong) CLLocation *currentLocation;

///
@property (nonatomic, strong) Reachability *reach;


@property (nonatomic) float distance;


@property (nonatomic) double timeToNextRequest;
@end


@implementation SRBeaconManager

/**
 creates a shared instance of beacon manager and returns
 @return returns created and initialized beacon manager object
 */
+ (instancetype)sharedInstance
{
    static SRBeaconManager *sharedInstance;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SRBeaconManager alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
        _locationManager.distanceFilter = 500;
        _timeToNextRequest = baseDelayRequestTime;
        _rangedBeacons = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)setTimeToNextRequest:(double)timeToNextRequest {
    if (timeToNextRequest > 3600)
        _timeToNextRequest = 3600;
    else
        _timeToNextRequest = timeToNextRequest;
}

#pragma mark - Public

- (void)startForGender:(SRGender)gender
{
    [self beginBackgroundTask];
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    self.appKey = bundleIdentifier;
    self.gender = gender;
    self.reach = [Reachability reachabilityWithHostname:@"www.google.com"];
    if ([CLLocationManager significantLocationChangeMonitoringAvailable])
        [_locationManager startMonitoringSignificantLocationChanges];
    else
        [_locationManager startUpdatingLocation];
}

/**
 handle action
 @param notification: local notification to handle
 */
- (void)handleNotification:(UILocalNotification *)notification {
    
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    
    NSDictionary *userInfo = notification.userInfo;
    
    NSString *question  = (userInfo[kQuestion] != [NSNull null] ? userInfo[kQuestion] : nil);
    
    if (!question) {
        return;
    }
    
    //  show alert user with question message
    SRAlertView *alertView = [[SRAlertView alloc] initWithTitle:@""
                                                        message:question
                                                       delegate:self
                                              cancelButtonTitle:@"Yes"
                                              otherButtonTitles:@"No", nil];
    
    alertView.userInfo = userInfo;
    
    [alertView show];
}

- (void)stop {
    [self.locationManager stopMonitoringSignificantLocationChanges];
    [self.locationManager stopUpdatingLocation];
    if (self.rangedBeacons) {
        [self.rangedBeacons removeAllObjects];
    }
    NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                              NSUserDomainMask, YES) objectAtIndex:0];
    NSString *plistPath = [[rootPath stringByAppendingPathComponent:kAppDataDirectory] stringByAppendingPathComponent:kAppDataFileName];
    [[NSFileManager defaultManager] removeItemAtPath:plistPath error:nil];
    for (CLBeaconRegion *beaconRegion in [[self.locationManager rangedRegions] allObjects])
        [self.locationManager stopRangingBeaconsInRegion:beaconRegion];
    
    for (CLBeaconRegion *beaconRegion in [[self.locationManager monitoredRegions] allObjects])
        [self.locationManager stopMonitoringForRegion:beaconRegion];
    [self endBackgroundTask];
}

#pragma mark - Data saving and updating

- (void)pushInfo {
    NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                              NSUserDomainMask, YES) objectAtIndex:0];
    NSString *plistPath = [[rootPath stringByAppendingPathComponent:kAppDataDirectory] stringByAppendingPathComponent:kAppDataFileName];
    [[NSFileManager defaultManager] createDirectoryAtPath:[rootPath stringByAppendingPathComponent:kAppDataDirectory] withIntermediateDirectories:YES attributes:nil error:nil];
    NSMutableData *data2write = [[NSMutableData alloc] init];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data2write];
    [archiver encodeObject:_rangedBeacons forKey:kAppData];
    [archiver finishEncoding];
    if (![data2write writeToFile:plistPath atomically:YES])
        NSLog(@"Error writing to file");
}

- (void)pullInfo {
    if (self.rangedBeacons)
        return;
    NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                              NSUserDomainMask, YES) objectAtIndex:0];
    NSString *plistPath = [[rootPath stringByAppendingPathComponent:kAppDataDirectory] stringByAppendingPathComponent:kAppDataFileName];
    NSMutableData *info2parse = [NSMutableData dataWithContentsOfFile:plistPath];
    if (!info2parse)
        return;
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:info2parse];
    _rangedBeacons = [unarchiver decodeObjectForKey:kAppData];
    [unarchiver finishDecoding];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if ([alertView isKindOfClass:[SRAlertView class]]) {
        
        
        NSDictionary *userInfo = [(SRAlertView *)alertView userInfo];
        
        SRAction action     = [userInfo[kAction] intValue];
        NSString *resource  = userInfo[kResource] != [NSNull null] ? userInfo[kResource] : nil;
        
        NSMutableDictionary *moteInfo = [[NSMutableDictionary alloc] initWithDictionary:userInfo];
        action = [moteInfo[kAction] intValue];
        NSString *actionString = nil;
        actionString = [self stringFromAction:action];
        moteInfo[kAction] = actionString;
        moteInfo[kMessage] = ([alertView cancelButtonIndex] == buttonIndex) ? kMessageYES : kMessageNO;
        [self requestConfirmMote:moteInfo];

        
        switch (action) {
            case SRActionText:
            {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Alert"
                                                                message:resource ? resource : @""
                                                               delegate:self
                                                      cancelButtonTitle:@"Ok"
                                                      otherButtonTitles:nil, nil];
                [alert show];
            }
                break;
                
            case SRActionImage:
            {
                if (resource) {
                    
                    NSURL *imageURL = [NSURL URLWithString:[resource stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                    
                    SRBeaconAdView *adView = [[SRBeaconAdView alloc] initWithURL:imageURL];
                    [adView show];
                }
                
            }
                break;
                
            case SRActionVideo:
            {
                if (resource) {
                    NSURL *videoURL = [NSURL URLWithString:[resource stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                    [[UIApplication sharedApplication] openURL:videoURL];
                    
                }
            }
                break;
                
            case SRActionTVVideo:
            case SRActionTVImage:
            {
            }
                break;
                
            default:
                break;
        }
    }
}

#pragma mark - Privates

/**
 show new notification by removing all of old those from notification center
 this notify user that one beacon is detected with question info message through local notification
 @param beacon: beacon detected
 */
- (void)sendNotificationForBeacon:(SRBeacon *)beacon {
    
    if (![self shouldNotifyForBeacon:beacon]) {
        DLog(@"=======> %s notification is disabled for a moment", __FUNCTION__);
        return;
    }
    
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.userInfo = @{kAction: @(beacon.action),
                              kResource: beacon.resource ? beacon.resource : [NSNull null],
                              kQuestion: beacon.question ? beacon.question : [NSNull null],
                              kMote: beacon.beacon.proximityUUID.UUIDString,
                              kMajor: beacon.beacon.major,
                              kMinor: beacon.beacon.minor,
                              kApp: self.appKey,
                              kPlatform: @"ios",
                              kGender: (self.gender == SRGenderMale ? @"male" : @"female"),
                              kUUID: beacon.uuid
                              };
    notification.alertBody = beacon.question;
    notification.soundName = UILocalNotificationDefaultSoundName;
    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
    
}

/**
 start monitoring for regoin UUID list got from the server
 @param uuids: UUID list to monitor
 */
- (void)startRegionMonitoringForUUIDs:(NSArray *)uuids
{
    //  clear rangedBeacons
    if (self.rangedBeacons) {
        [self.rangedBeacons removeAllObjects];
        NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                                  NSUserDomainMask, YES) objectAtIndex:0];
        NSString *plistPath = [[rootPath stringByAppendingPathComponent:kAppDataDirectory] stringByAppendingPathComponent:kAppDataFileName];
        [[NSFileManager defaultManager] removeItemAtPath:plistPath error:nil];
    }
    
    // stop previous ranging & monitoring
    for (CLBeaconRegion *beaconRegion in [[self.locationManager rangedRegions] allObjects])
        [self.locationManager stopRangingBeaconsInRegion:beaconRegion];
    
    for (CLBeaconRegion *beaconRegion in [[self.locationManager monitoredRegions] allObjects])
        [self.locationManager stopMonitoringForRegion:beaconRegion];
    
    
    if (!uuids) {
        DLog(@"======> %s UUID list is NULL, please contact to service! aborting...", __FUNCTION__);
        return;
    }
    
    DAssert([uuids isKindOfClass:[NSArray class]]);
    
    if ([CLLocationManager isMonitoringAvailableForClass:[CLBeaconRegion class]]) {
        if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorized) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:@"Beacon Monitoring is not available"
                                                           delegate:nil
                                                  cancelButtonTitle:@"Ok"
                                                  otherButtonTitles:nil, nil];
            [alert show];
            return;
        }
    }
    else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:@"Beacon Monitoring is not available"
                                                       delegate:nil
                                              cancelButtonTitle:@"Ok"
                                              otherButtonTitles:nil, nil];
        [alert show];
        return;
        
    }
    
    if (uuids.count == 0) {
        DLog(@"======> %s UUID list is empty, please add motes in panel! aborting...", __FUNCTION__);
        return;
    }
    
    int index = 0;
    for (NSDictionary *moteDictionary in uuids)
    {
        //  start monitoring separately for each beacon of list
        if (![moteDictionary isKindOfClass:[NSDictionary class]]) {
            DLog(@"=========> %s wrong setting for mote in service", __FUNCTION__);
            continue;
        }
        if (!moteDictionary[kProximityUUID]) {
            DLog(@"=========> %s wrong setting of proximity UUID for mote in service", __FUNCTION__);
            continue;
        }
        if (!moteDictionary[kMajor]) {
            DLog(@"=========> %s wrong setting of major for mote in service", __FUNCTION__);
            continue;
        }
        if (!moteDictionary[kMinor]) {
            DLog(@"=========> %s wrong setting of minor for mote in service", __FUNCTION__);
            continue;
        }
        
        CLBeaconMajorValue major = [moteDictionary[kMajor] intValue];
        CLBeaconMinorValue minor = [moteDictionary[kMinor] intValue];
        NSString *uuidString = moteDictionary[kProximityUUID];
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
        
        if (!uuid) {
            DLog(@"========> %s : UUID got from the server is invalid", __FUNCTION__);
            continue;
        }
        
        CLBeaconRegion *beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid
                                                                               major:major
                                                                               minor:minor
                                                                          identifier:[NSString stringWithFormat:@"com.skurun.mote%d", index ++]];
        [self.locationManager startMonitoringForRegion:beaconRegion];
        DLog(@"=========> %s : %@", __FUNCTION__, beaconRegion.identifier);
    }
    [self endBackgroundTask];
}

//  MARK: utility methods
/**
 convert from action string to SRAction enum value
 @param actionString: action string to convert
 @return returns SRAction enum value
 */
- (SRAction)actionFromString:(NSString *)actionString {
    
    DAssert(actionString);
    
    if ([actionString isEqualToString:kActionText]) {
        return SRActionText;
    }
    else if ([actionString isEqualToString:kActionImage]) {
        return SRActionImage;
    }
    else if ([actionString isEqualToString:kActionVideo]) {
        return SRActionVideo;
    }
    else if ([actionString isEqualToString:kActionTVImage]) {
        return SRActionTVImage;
    }
    else if ([actionString isEqualToString:kActionTVVideo]) {
        return SRActionTVVideo;
    }
    
    return SRActionNone;
}

/**
 convert from SRAction to action string actionString
 @param action: SRAction to convert
 @return returns associagted action string
 */
- (NSString *)stringFromAction:(SRAction)action {
    switch (action) {
        case SRActionText:
            return kActionText;
        case SRActionImage:
            return kActionImage;
        case SRActionVideo:
            return kActionVideo;
        case SRActionTVImage:
            return kActionTVImage;
        case SRActionTVVideo:
            return kActionTVVideo;
        default:
            return @"";
    }
}

//  MARK: background tasking

/**
 mark begining of current background task
 */
- (void)beginBackgroundTask {
    [self endBackgroundTask];
    self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self endBackgroundTask];
    }];
}

/**
 mark ending of background task
 */
- (void)endBackgroundTask {
    if (self.backgroundTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
        self.backgroundTask = UIBackgroundTaskInvalid;
    }
}

//  MARK: refine of mote list got from the server
/**
 remove duplication from mote list
 @param param: description
 @return returns description
 */
- (NSArray *)removeDuplicationFromArray:(NSArray *)moteArray {
    if (!moteArray) {
        return nil;
    }
    DAssert([moteArray isKindOfClass:[NSArray class]]);
    if (moteArray.count == 0) {
        return nil;
    }
    
    NSMutableArray *resultArray = [[NSMutableArray alloc] init];
    
    NSDictionary *moteDictionary = nil;
    for (int i = 0; i < moteArray.count; i++) {
        moteDictionary = moteArray[i];
        if ([self containsMote:moteDictionary inArray:resultArray]) {
            continue;
        }
        
        [resultArray addObject:moteDictionary];
    }
    
    return resultArray;
}

/**
 check if mote array contains a specific mote in it
 @param moteDictionary: mote to find
 @param moteArray: mote array to look in
 @return returns YES if mote array contains mote, else returns NO
 */
- (BOOL)containsMote:(NSDictionary *)moteDictionary inArray:(NSArray *)moteArray {
    for (NSDictionary *dictionary in moteArray) {
        if ([self isEqualMote:moteDictionary withMote:dictionary]) {
            return YES;
        }
    }
    
    return NO;
}

/**
 check duplication of two mote dictionary
 @param firstMote: first mote dictoanry to compare
 @param secondMote: second mote dictionary to compare
 @return returns YES if first mote and second mote are same one, else returns NO
 */
- (BOOL)isEqualMote:(NSDictionary *)firstMote withMote:(NSDictionary *)secondMote
{
    if (!firstMote) {
        return NO;
    }
    if (!secondMote) {
        return NO;
    }
    if (![firstMote isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    if (![secondMote isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    
    NSString *firstUUID = firstMote[@"uuid"];
    CLBeaconMajorValue firstMajor = [firstMote[@"major"] intValue];
    CLBeaconMinorValue firstMinor = [firstMote[@"minor"] intValue];
    NSString *secondUUID = secondMote[@"uuid"];
    CLBeaconMajorValue secondMajor = [secondMote[@"major"] intValue];
    CLBeaconMajorValue secondMinor = [secondMote[@"minor"] intValue];
    
    if ([firstUUID isEqualToString:secondUUID] && firstMajor == secondMajor && firstMinor == secondMinor) {
        return YES;
    }
    
    return NO;
}

//  MARK: operation for rangedBeacons model

/**
 add ranged beacon to the model
 if beacon is already added in the model, skip simply
 @param beacon: beacon to add
 */
- (void)addBeacon:(SRBeacon *)newBeacon {
    for (SRBeacon *beacon in self.rangedBeacons) {
        if ([newBeacon isEqual:beacon]) {
            return;
        }
    }
    
    [self.rangedBeacons addObject:newBeacon];
    [self pushInfo];
}

/**
 find & get registered beacon from model
 @param beacon: beacon to find from model
 @return returns beacon found from model
 */
- (SRBeacon *)searchForBeacon:(SRBeacon *)beacon {
    for (SRBeacon *registeredBeacon in self.rangedBeacons) {
        if ([registeredBeacon isEqual:beacon]) {
            return registeredBeacon;
        }
    }
    
    return nil;
}

// MARK: repeat decision

/**
 update beacon info with new one
 @param newBeacon: new beacon info
 */
- (void)updateWithBeacon:(SRBeacon *)newBeacon {
    SRBeacon *registeredBeacon = [self searchForBeacon:newBeacon];
    NSUInteger index = [self.rangedBeacons indexOfObject:registeredBeacon];
    // update beacon info with new info
    [self.rangedBeacons replaceObjectAtIndex:index
                                  withObject:newBeacon];
    [self pushInfo];
}

/**
 check whether notiying of specific beacon detection is possible or not
 @param beacon: beacon ranged newly
 @return returns YES if it should notify beacon detection, else returns NO
 */
- (BOOL)shouldNotifyForBeacon:(SRBeacon *)beacon {
    
    SRBeacon *registeredBeacon = [self searchForBeacon:beacon];
    
    if (registeredBeacon == beacon) {
        return YES;
    }
    
    NSTimeInterval timeInterval = [beacon.moniteredDate timeIntervalSinceDate:registeredBeacon.moniteredDate];
    if (timeInterval > registeredBeacon.repeatInterval * 60 && registeredBeacon.repeat) {
        [self updateWithBeacon:beacon];
        return YES;
    }
    
    return NO;
}


#pragma mark - Server API

/**
 send request after time, that changes expanently
 @param requestType: type of request to do
 */
- (void)delayedRequest:(SRRequest)requestType withInfo:(id)userInfo{
    __weak typeof(self) wself = self;
    [self setTimeToNextRequest:_timeToNextRequest*2];
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.timeToNextRequest * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        switch (requestType) {
            case SRRequestActionForBecon:
                [wself requestActionForBeacon:userInfo];
                break;
            case SRRequestBeaconList:
                [wself requestBeaconList];
                break;
            case SRRequestConfirmMote:
                [wself requestConfirmMote:userInfo];
            default:
                break;
        }
    });
}

/**
 * get the list of motes registered for the app from the server.
 */
- (void)requestBeaconList {
    __weak typeof(self) wself = self;
    
    if (self.currentLocation == nil) {
        return;
    }
    
    NSDictionary *params = @{kApp: self.appKey,
                             kPlatform: @"ios",
                             kLatitude: [NSString stringWithFormat:@"%.3f",self.currentLocation.coordinate.latitude],
                             kLongitude: [NSString stringWithFormat:@"%.3f",self.currentLocation.coordinate.longitude],
                             kDistance: [NSString stringWithFormat:@"%.3f", self.distance]};
    
    
    
    DLog(@"=========> %s", __FUNCTION__);
    
    [[SRSessionManager sharedInstance] POST:kMoteList parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        if (!wself) {
            return;
        }
        [wself.reach stopNotifier];
        
        NSDictionary *responseDictionary = (NSDictionary *)responseObject;
        
        if (!responseDictionary) {
            DLog(@"=========> %s no response, will retry 5 secs or more later", __FUNCTION__);
            [wself delayedRequest:SRRequestBeaconList withInfo:nil];
            return;
        }
        
        DLog(@"=======> %s response beacon list: %@", __FUNCTION__, responseDictionary);
        
        if (![responseDictionary isKindOfClass:[NSDictionary class]]) {
            DLog(@"=========> %s wrong response, will retry 5 secs later", __FUNCTION__);
            [wself delayedRequest:SRRequestBeaconList withInfo:nil];
            return;
        }
        
        
        id errors = responseDictionary[kErrors];
        if (errors) {
            DLog(@"=======> %s error repsonse: %@, will retry 5 secs or more later", __FUNCTION__, errors);
            [wself delayedRequest:SRRequestBeaconList withInfo:nil];
            return;
        }
        
        //  remove duplicated motes from the mote array
        NSArray *moteArray = [self removeDuplicationFromArray:responseDictionary[@"motes"]];
        
        if (moteArray.count > 20)
        {
            wself.distance *= 0.8;
            [wself delayedRequest:SRRequestBeaconList withInfo:nil];
        }
        else
        {
            wself.timeToNextRequest = baseDelayRequestTime;
            [wself startRegionMonitoringForUUIDs:moteArray];
        }
        
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        DLog(@"=======> %s failed, so retrying 5 sedcs later", __FUNCTION__);
        if (error.code == NSURLErrorNotConnectedToInternet) {
            wself.reach.reachableBlock = ^(Reachability *reach) {
                [wself requestBeaconList];
            };
            [wself.reach startNotifier];
        }
        else
            [wself delayedRequest:SRRequestBeaconList withInfo:nil];
    }];
}


/**
 requset acton to the server for a specific beacon
 @param beacon: beacon to request action for
 */
- (void)requestActionForBeacon:(SRBeacon *)beacon {
    
    NSDictionary *params = @{kApp: self.appKey,
                             kPlatform: @"ios",
                             kMote: beacon.beacon.proximityUUID.UUIDString,
                             kMajor: beacon.beacon.major,
                             kMinor: beacon.beacon.minor,
                             kRSSI: [NSNumber numberWithInteger:beacon.beacon.rssi],
                             kGender: (self.gender == SRGenderMale ? @"male" : @"female")};
    
    DLog(@"========> %s %@", __FUNCTION__, params);
    
    __weak typeof(self) wself = self;
    
    
    [[SRSessionManager sharedInstance] POST:kMotes parameters:params success:^(NSURLSessionDataTask *task, id responseObject) {
        if (!wself) {
            return;
        }
        [wself.reach stopNotifier];
        
        NSDictionary *responseDictionary = (NSDictionary *)responseObject;
        
        DLog(@"==========> %s %@", __FUNCTION__, responseDictionary);
        
        if (!responseDictionary || ![responseDictionary isKindOfClass:[NSDictionary class]]) {
            DLog(@"======> %s response is not correct json string, please contact to service, aborting...", __FUNCTION__);
            return;
        }
        
        id errors = responseDictionary[kErrors];
        if (errors) {
            DLog(@"======> %s error response, please setting for this beacon: %@, aborting...", __FUNCTION__, errors);
            return;
        }
        
        wself.timeToNextRequest = baseDelayRequestTime;
        
        id action = responseDictionary[kAction];
        
        beacon.action = SRActionNone;
        if (action && action != [NSNull null]) {
            
            NSString *actionString = action;
            
            beacon.action = [self actionFromString:actionString];
        }
        
        id question = responseDictionary[kQuestion];
        if (question && question != [NSNull null]) {
            beacon.question = question;
        }
        
        id resource = responseDictionary[kResource];
        if (resource && resource != [NSNull null]) {
            beacon.resource = resource;
        }
        
        id repeat = responseDictionary[kRepeat];
        if (repeat && repeat != [NSNull null]) {
            beacon.repeat = [repeat boolValue];
        }
        
        id uuid = responseDictionary[kUUID];
        if (uuid && uuid != [NSNull null])
            beacon.uuid = uuid;
        
        id repeatInterval = responseDictionary[kRepeatInterval];
        if (repeatInterval && repeatInterval != [NSNull null]) {
            beacon.repeatInterval = [repeatInterval integerValue];
        }
        
        [wself pullInfo];
        
        [wself addBeacon:beacon];
        
        if (beacon.action != SRActionNone) {
            [wself sendNotificationForBeacon:beacon];
        }
        
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        DLog(@"=======> %s %@, so retrying....", __FUNCTION__, [error localizedDescription]);
        if (error.code == NSURLErrorNotConnectedToInternet) {
            wself.reach.reachableBlock = ^(Reachability *reach) {
                [wself delayedRequest:SRRequestActionForBecon withInfo:beacon];
            };
            [wself.reach startNotifier];
        }
        else
            [wself delayedRequest:SRRequestActionForBecon withInfo:beacon];
    }];
}

/**
 send confirm POST requset to the server for TV actions
 @param moteDictioanry: notificaton user info dictionary included mote info and action info from the server through /motes/discover
 */
- (void)requestConfirmMote:(NSDictionary *)moteDictioanry {
    
    
    DLog(@"========> %s mote to confirm: %@", __FUNCTION__, moteDictioanry);
    
    __weak typeof(self) wself = self;
    
    [[SRSessionManager sharedInstance] POST:kMotesConfirm parameters:moteDictioanry success:^(NSURLSessionDataTask *task, id responseObject) {
        if (!wself) {
            return;
        }
        [wself.reach stopNotifier];
        
        NSDictionary *responseDictionary = (NSDictionary *)responseObject;
        
        DLog(@"==========> %s %@", __FUNCTION__, responseDictionary);
        
        if (!responseDictionary || ![responseDictionary isKindOfClass:[NSDictionary class]]) {
            DLog(@"======> %s response is invalid string, please contact to service, aborting...", __FUNCTION__);
            return;
        }
        
        id errors = responseDictionary[kErrors];
        if (errors) {
            DLog(@"======> %s error response, check mote settings in the panel aborting...", __FUNCTION__);
            return;
        }
        wself.timeToNextRequest = baseDelayRequestTime;
        DLog(@"======> %s confirmed successfuly this mote", __FUNCTION__);
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        DLog(@"=======> %s %@, so retrying...", __FUNCTION__, [error localizedDescription]);
        if (error.code == NSURLErrorNotConnectedToInternet) {
            wself.reach.reachableBlock = ^(Reachability *reach) {
                [wself delayedRequest:SRRequestConfirmMote withInfo:moteDictioanry];
            };
            [wself.reach startNotifier];
        }
        else
            [wself delayedRequest:SRRequestConfirmMote withInfo:moteDictioanry];
    }];
}


#pragma mark - CLLocationManagerDelegate
// MARK: getting location
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    [self beginBackgroundTask];
    self.currentLocation = [locations lastObject];
    self.distance =  MAX(self.currentLocation.horizontalAccuracy * 2 / 1600, 1.0);
    [self requestBeaconList];
}

//  MARK: monitoring

- (void)locationManager:(CLLocationManager *)manager
      didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region
{
    [self beginBackgroundTask];
    CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
    
    if (state == CLRegionStateInside) {
        DLog(@"=========> didDetermineState for INSIDE of: %@", beaconRegion.identifier);
        [self.locationManager startRangingBeaconsInRegion:beaconRegion];
    }
    else if (state == CLRegionStateOutside) {
        DLog(@"=========> didDetermineState for OUTSIDE of: %@", beaconRegion.identifier);
        [self.locationManager stopRangingBeaconsInRegion:beaconRegion];
    }
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error
{
    CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
    if (error.code == kCLErrorRegionMonitoringFailure)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:@"Some error occured. Maybe Bluetooth is disabled."
                                                       delegate:nil
                                              cancelButtonTitle:@"Ok"
                                              otherButtonTitles:nil, nil];
        [alert show];
    }
    if (error.code == kCLErrorRegionMonitoringDenied)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:@"Background App Refresh in Settings/General need to be enabled"
                                                       delegate:nil
                                              cancelButtonTitle:@"Ok"
                                              otherButtonTitles:nil, nil];
        [alert show];
    }
    DLog(@"==========> %s %@, *** error *** please check your phone settings!, %@", __FUNCTION__, beaconRegion.identifier, error.localizedDescription);
}

//  MARK: ranging
- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
    DLog(@"===========> %s %@: %@: %d: %d", __FUNCTION__, region.identifier,region.proximityUUID.UUIDString, [region.major intValue], [region.minor intValue]);
    
    if (beacons && beacons.count > 0) {
        [self.locationManager stopRangingBeaconsInRegion:region];
        
        //  add ranged beacon to the model
        SRBeacon *beacon = [[SRBeacon alloc] initWithCLBeacon:beacons[0]];
        beacon.moniteredDate = [NSDate date];
        
        [self requestActionForBeacon:beacon];
    }
}

- (void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error
{
    DLog(@"==========> %s %@, *** error *** %@", __FUNCTION__, region.identifier, error.localizedDescription);
}

@end
