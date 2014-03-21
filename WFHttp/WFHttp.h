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
 Singleton instance to access manager from anywhere
 */
+(id)sharedWFHttp;

#pragma mark - Standard requests
/*
 Basic GET request. Results return in the completion block
 */
+(void)GET:(NSString*)url completion:(void(^)(id result))completion;

/*
 Basic POST request. Results return in the completion block
 Object can be anything (array, dictionary, NSObject, and more)
 */
+(void)POST:(NSString*)url object:(id)object completion:(void(^)(id result))completion;

#pragma mark - Queue requests
/*
 Create a post request but instead of sending immediately, it adds to a queue to be sent after
 the threshold specified
 */
+(void)POSTToQueue:(NSString *)url object:(id)object;

/*
 Sends all enqueued requests
 */
+(void)sendQueue;

/*
 Returns the count of requests waiting to be sent
 */
+(int)postRequestsInQueue;

#pragma mark - Instance

/*
 Sends all enqueued requests
 Uses a slightly different implementation to support background mode once
 app has exited
 */
-(void)purgeQueue;

@end






