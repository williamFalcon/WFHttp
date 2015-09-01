//
//  WFHttp+ReachabilityHelper.m
//  Testee
//
//  Created by William Falcon on 9/1/15.
//  Copyright (c) 2015 William Falcon. All rights reserved.
//

#import "WFHttp+ReachabilityHelper.h"
#import "Reachability.h"

@implementation WFHttp (ReachabilityHelper)

/*
 Use reachability to check internet connection. If any is available, return YES
 */
+ (BOOL)internetReachable{
    
    NetworkStatus netStatus = [[Reachability reachabilityForInternetConnection] currentReachabilityStatus];
    
    //post reachability notification so listeners can respond if network changed
    [[NSNotificationCenter defaultCenter]postNotificationName:kReachabilityChangedNotification object:nil];
    
    return netStatus != NotReachable;
}
@end
