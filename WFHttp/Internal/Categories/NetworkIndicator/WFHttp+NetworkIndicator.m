//
//  WFHttp+NetworkIndicator.m
//  Testee
//
//  Created by William Falcon on 9/1/15.
//  Copyright (c) 2015 William Falcon. All rights reserved.
//

#import "WFHttp+NetworkIndicator.h"
#import "WFHttp+Singleton.h"
@import UIKit;

@implementation WFHttp (NetworkIndicator)

/*
 Increase the count of indicators by one
 */
+(void)handleNetworkIndicator{
    
    NSMutableArray *requestsInProgress = [[WFHttp sharedWFHttp]requestsInProgress];
    
    if (requestsInProgress.count>0) {
        
        //start indicator
        if (![[UIApplication sharedApplication]isNetworkActivityIndicatorVisible]) {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        }
        
    }else{
        
        //stop indicator
        if ([[UIApplication sharedApplication]isNetworkActivityIndicatorVisible]) {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        }
    }
}

@end
