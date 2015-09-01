//
//  WFHttp+Singleton.m
//  Testee
//
//  Created by William Falcon on 9/1/15.
//  Copyright (c) 2015 William Falcon. All rights reserved.
//

#import "WFHttp+Singleton.h"
#import "WFHttp+Cookies.h"

@implementation WFHttp (Singleton)

#pragma mark - Singleton
+(id)sharedWFHttp{
    
    static id WFHttp = nil;
    
    if (!WFHttp) {
        WFHttp = [[self alloc]init];
        
        //get current cookie policy
        NSHTTPCookieAcceptPolicy currentPolicy = [[NSHTTPCookieStorage sharedHTTPCookieStorage]cookieAcceptPolicy];
        NSHTTPCookieAcceptPolicy savedPolicy = [[NSUserDefaults standardUserDefaults] integerForKey:POLICY_KEY];
        
        //change only once by default
        if (currentPolicy != savedPolicy) {
            [[NSHTTPCookieStorage sharedHTTPCookieStorage]setCookieAcceptPolicy:savedPolicy];
        }
    }
    
    return WFHttp;
}

@end
