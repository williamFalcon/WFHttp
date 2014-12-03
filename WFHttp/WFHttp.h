//
//  WFHttp.h
//  WFHttp
//
//  Created by William Falcon on 3/20/14.
//  Copyright (c) 2014 William Falcon. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WFHttp : NSObject

/*
 Will auto empty once this threshold has been reached.
 Defaults to 50 unless modified
 */
@property (assign) int queueEmptyThreshold;

/*
Determines how cookies will be handled.
Defaults to NSHTTPCookieAcceptPolicyAlways
*/
@property (assign) NSHTTPCookieAcceptPolicy cookiePolicy;

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

#pragma mark - Standard requests
/*
 Basic GET request. Results return in the completion block
 */
+(void)GET:(NSString*)url optionalParameters:(NSDictionary *)parameters optionalHTTPHeaders:(NSDictionary *)headers completion:(void(^)(id result, NSInteger statusCode, NSHTTPURLResponse *response))completion;

/*
 Basic POST request. Results return in the completion block
 Object can be anything (array, dictionary, NSObject, and more)
 */
+(void)POST:(NSString*)url optionalHTTPHeaders:(NSDictionary *)headers object:(id)object completion:(void(^)(id result, NSInteger statusCode, NSHTTPURLResponse *response))completion;

/*
 Basic PUT request. Results return in the completion block
 Object can be anything (array, dictionary, NSObject, and more)
 */
+(void)PUT:(NSString*)url optionalHTTPHeaders:(NSDictionary *)headers object:(id)object completion:(void(^)(id result, NSInteger statusCode, NSHTTPURLResponse *response))completion;

#pragma mark - Queue requests
/*
 Create a post request but instead of sending immediately, it adds to a queue to be sent after
 the threshold specified
 */
+(void)POSTToQueue:(NSString *)url optionalHTTPHeaders:(NSDictionary *)headers object:(id)object;

/*
 Sends all enqueued requests
 */
+(void)sendQueue;

/*
 Returns the count of requests waiting to be sent
 */
+(int)postRequestsInQueue;

#pragma mark - Parsers

/*
Serializes an objective-C object
*/
+(NSDictionary *)createObjectDictionaryFromObject:(id)object;

#pragma mark - Instance methods

/*
 Sends all enqueued requests
 Uses a slightly different implementation to support background mode once
 app has exited
 */
-(void)purgeQueue;


@end






