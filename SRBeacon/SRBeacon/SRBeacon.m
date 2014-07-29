//
//  SRBeacon.m
//  Pods
//
//  Created by cuterabbit on 2/5/14.
//
//

#import "SRBeacon.h"

NSString * const kCodingBeacon          = @"beacon";
NSString * const kCodingRepeat          = @"repeat";
NSString * const kCodingRepeatInterval  = @"repeatInterval";
NSString * const kCodingMonitoredDate   = @"moitoredDate";

@implementation SRBeacon

#pragma mark - NSCoding protocol



- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_beacon forKey:kCodingBeacon];
    [aCoder encodeObject:_moniteredDate forKey:kCodingMonitoredDate];
    [aCoder encodeBool:_repeat forKey:kCodingRepeat];
    [aCoder encodeInt:_repeatInterval forKey:kCodingRepeatInterval];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self)
    {
        _beacon = [aDecoder decodeObjectForKey:kCodingBeacon];
        _moniteredDate = [aDecoder decodeObjectForKey:kCodingMonitoredDate];
        _repeat = [aDecoder decodeBoolForKey:kCodingRepeat];
        _repeatInterval = [aDecoder decodeIntForKey:kCodingRepeatInterval];
        _action = SRActionNone;
        _question = nil;
        _limitOfRSSI = 0;
        _resource = nil;
    }
    return self;
    
}

- (instancetype)initWithCLBeacon:(CLBeacon *)beacon
{
    self = [super init];
    if (self) {
        _beacon = beacon;
        _limitOfRSSI = 0;
        _moniteredDate = nil;
        _question = nil;
        _resource = nil;
        _action = SRActionNone;
        _repeat = NO;
        _repeatInterval = -1;
    }
    return self;
}

#pragma mark - Public

- (BOOL)isEqual:(id)object {
    if (!object) {
        return NO;
    }
    if (![object isKindOfClass:[SRBeacon class]]) {
        return NO;
    }
    
    SRBeacon *beacon = (SRBeacon *)object;
    if ([beacon.beacon.proximityUUID isEqual:self.beacon.proximityUUID]
        && beacon.beacon.major.intValue == self.beacon.major.intValue
        && beacon.beacon.minor.intValue == self.beacon.minor.intValue) {
        return YES;
    }
    
    return NO;
}

- (BOOL)isEqualToCLBeacon:(CLBeacon *)beacon
{
    return ([self.beacon.proximityUUID isEqual:beacon.proximityUUID] &&
            [self.beacon.major isEqualToNumber:beacon.major] &&
            [self.beacon.minor isEqualToNumber:beacon.minor]);
}

- (BOOL)canBeRanged
{
    
    // limitOfRSSI of each motes is configured on the admin panel
    if (self.limitOfRSSI != 0 && self.beacon.rssi > self.limitOfRSSI)
        return NO;
    
    //a mote should be deteted again after 5 mins since detected
    if (self.moniteredDate && [[NSDate date] timeIntervalSinceDate:self.moniteredDate] < MOTE_EXPIRE_INTERVAL) {
        return NO;
    }
    
    return YES;
}

- (NSString *)identifier
{
    if (self.beacon) {
        
        return [SRBeacon identifierForCLBeacon:self.beacon];
    }
    
    return nil;
}

+ (NSString *)identifierForCLBeacon:(CLBeacon *)beacon
{
    return [NSString stringWithFormat:@"%@:%@:%@", [beacon.proximityUUID UUIDString], beacon.major, beacon.minor];
}

@end
