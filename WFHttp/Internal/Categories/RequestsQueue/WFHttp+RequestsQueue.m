//
//  WFHttp+RequestsQueue.m
//  Testee
//
//  Created by William Falcon on 9/1/15.
//  Copyright (c) 2015 William Falcon. All rights reserved.
//

#import "WFHttp+RequestsQueue.h"
#import "WFHttp+Singleton.h"
#import "WFHttp+ReachabilityHelper.h"
#import "WFHttp+NetworkIndicator.h"

@implementation WFHttp (RequestsQueue)

+(void)sendQueue{
    
    if ([self internetReachable]) {
        
        NSMutableArray *requests = [[WFHttp sharedWFHttp]requests];
        for (NSMutableURLRequest *request in requests) {
            
            //increase requests count
            [[[WFHttp sharedWFHttp]requestsInProgress] addObject:@""];
            
            NSOperationQueue *queue = [[NSOperationQueue alloc] init];
            [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                
                
                if (connectionError) {
                    NSLog(@"%@",connectionError);
                }
                
                //decrease requests count
                [[[WFHttp sharedWFHttp]requestsInProgress] removeLastObject];
                [WFHttp handleNetworkIndicator];
                
            }];
        }
        
        //clear the q
        [requests removeAllObjects];
        [WFHttp handleNetworkIndicator];
    }else{
        NSLog(@"No internet connection");
    }
}

+(int)postRequestsInQueue{
    unsigned long count = [[[WFHttp sharedWFHttp]requests]count];
    return (int)count;
}

-(void)purgeQueue{
    
    //empty all requests in a slightly different manner so we can send after app finishes
    NSMutableArray *requests = [[WFHttp sharedWFHttp]requests];
    
    // Start the long-running task and return immediately.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //send the requests on the background after app has finished
        for (NSMutableURLRequest *request in requests) {
            NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
            
            //Start
            [connection start];
        }
        
        [requests removeAllObjects];
    });
}

@end
