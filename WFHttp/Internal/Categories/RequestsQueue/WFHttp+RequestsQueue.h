//
//  WFHttp+RequestsQueue.h
//  Testee
//
//  Created by William Falcon on 9/1/15.
//  Copyright (c) 2015 William Falcon. All rights reserved.
//

#import "WFHttp.h"

@interface WFHttp (RequestsQueue)

/*
 Sends all enqueued requests
 */
+(void)sendQueue;

/*
 Returns the count of requests waiting to be sent
 */
+(int)postRequestsInQueue;

/*
 Sends all enqueued requests
 Uses a slightly different implementation to support background mode once
 app has exited
 */
-(void)purgeQueue;

@end
