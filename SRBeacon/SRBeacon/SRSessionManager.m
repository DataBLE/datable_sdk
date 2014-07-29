//
//  SRSessionManager.m
//  Pods
//
//  Created by cuterabbit on 2/10/14.
//
//

#import "SRSessionManager.h"

NSString * const kServer = @"http://protected-springs-5667.herokuapp.com";

@implementation SRSessionManager

- (instancetype)init
{
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURL *url = [NSURL URLWithString:[kServer stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    self = [super initWithBaseURL:url sessionConfiguration:configuration];
    if (self) {
        configuration.timeoutIntervalForRequest = 10;
    }
    return self;
}

#pragma mark - Public

+ (instancetype)sharedInstance {
    static SRSessionManager *manager = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    
    return manager;
}

@end
