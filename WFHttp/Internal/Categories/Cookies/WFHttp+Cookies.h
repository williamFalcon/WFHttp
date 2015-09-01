//
//  WFHttp+Cookies.h
//  Testee
//
//  Created by William Falcon on 9/1/15.
//  Copyright (c) 2015 William Falcon. All rights reserved.
//

#import "WFHttp.h"

static NSString *POLICY_KEY = @"WFHTTP cookie policy";
@interface WFHttp (Cookies)

#pragma mark - Session management

/*
 If cookiePolicy is set to NSHTTPCookieAcceptPolicyAlways, then
 this method will let you know the status of the session.
 If expired, the session cookie is no longer good.
 */
+ (BOOL)isSessionCookieExpired;

/*
 Removes all saved cookies
 */
+ (void)clearCookies;

/**
 Modifies the cookie policy
 */
+(void)setCookiePolicy:(NSHTTPCookieAcceptPolicy)cookiePolicy;

@end
