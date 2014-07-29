//
//  SRSessionManager.h
//  Pods
//
//  Created by cuterabbit on 2/10/14.
//
//

#import "AFHTTPSessionManager.h"

/**
 SRSessionManager is subclass of AFHTTPSessoinManager
 This is initialized with SRBeacon service root path and custom configuration for this system and used for making calls to the SRBeacon service
 */
@interface SRSessionManager : AFHTTPSessionManager

/**
 initialize & returns shared instance of session manager by initializing with Base URL
 @return returns shared instance of session manager
 */
+ (instancetype)sharedInstance;

@end
