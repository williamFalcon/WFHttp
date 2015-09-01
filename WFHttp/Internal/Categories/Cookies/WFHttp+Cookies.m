//
//  WFHttp+Cookies.m
//  Testee
//
//  Created by William Falcon on 9/1/15.
//  Copyright (c) 2015 William Falcon. All rights reserved.
//

#import "WFHttp+Cookies.h"
#import "WFHttp+Singleton.h"

@implementation WFHttp (Cookies)

/**
 Checks to see if a stored cookie session has expired
 */
+ (BOOL)isSessionCookieExpired{
    
    BOOL result = true;
    
    //load cookie
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage]cookies];
    
    //error check
    if (cookies.count >0) {
        NSHTTPCookie *cookie = cookies[0];
        NSDate *now = [NSDate date];
        
        //determine if cookie expired
        BOOL didCookieExpire = [cookie.expiresDate compare:now] == NSOrderedAscending ? true : false;
        
        result = didCookieExpire;
    }
    
    return result;
}

+(void)clearCookies {
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *each in cookieStorage.cookies) {
        [cookieStorage deleteCookie:each];
    }
}


+ (void)setCookiePolicy:(NSHTTPCookieAcceptPolicy)cookiePolicy {
    
    [[WFHttp sharedWFHttp]setCookiePolicy:cookiePolicy];
    
    //update the policy
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]setCookieAcceptPolicy:cookiePolicy];
    [[NSUserDefaults standardUserDefaults]setInteger:cookiePolicy forKey:POLICY_KEY];
}

@end
