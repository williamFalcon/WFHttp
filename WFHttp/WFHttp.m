//
//  WFHttp.m
//  WFHttp
//
//  Created by William Falcon on 3/20/14.
//  Copyright (c) 2014 William Falcon. All rights reserved.
//

#import "WFHttp.h"
#import "WFHttp+FormBuilder.h"
#import "WFHttp+ReachabilityHelper.h"
#import "WFHttp+Parsing.h"
#import "WFHttp+Cookies.h"
#import "WFHttp+Singleton.h"
#import "WFHttp+StringHelpers.h"
#import "WFHttp+NetworkIndicator.h"
#import "WFHttp+RequestsQueue.h"

@import UIKit;

@interface WFHttp()

@end

@implementation WFHttp
@synthesize cookiePolicy = _cookiePolicy;



-(id)init{
    
    self = [super init];
    self.requests = [NSMutableArray new];
    self.requestsInProgress = [NSMutableArray new];
    
    self.queueEmptyThreshold = 4;
    
    //subscribe to resignActive so we can send all requests that have been enqueued
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(purgeQueue) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(purgeQueue) name:UIApplicationWillTerminateNotification object:nil];
    
    return self;
}

#pragma mark - GET

+ (void)GET:(NSString *)url optionalParameters:(NSDictionary *)parameters optionalHTTPHeaders:(NSDictionary *)headers onSuccess:(void (^)(id, NSInteger, NSHTTPURLResponse *))success onFailure:(void (^)(NSString *))failure {
    
    if ([self internetReachable]) {
        
        url = [WFHttp parametrizedUrl:url fromParameters:parameters];
        
        //increase requests count
        [[[WFHttp sharedWFHttp]requestsInProgress] addObject:@""];
        
        //Init request
        NSMutableURLRequest *request = [NSMutableURLRequest
                                        requestWithURL:[NSURL URLWithString:url]];
        
        //Set headers
        [request setHTTPMethod:@"GET"];
        [WFHttp addHeaders:headers toRequest:request];
        
        //log if requested
        if (LOGGING_ENABLED) {
            NSLog(@"\n\nWFHTTP-%@: %@",request.HTTPMethod ,url);
        }
        
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            
            //get the http headers
            NSHTTPURLResponse* newResp = (NSHTTPURLResponse*)response;
            NSString *contentType = [newResp allHeaderFields][@"Content-Type"];
            contentType = [contentType lowercaseString];
            
            //serialize if content type is JSON
            id jsonObj;
            if ([WFHttp string:contentType contains:@"json"] && response) {
                jsonObj = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
            }
            
            //log error
            if (connectionError) {
                NSLog(@"%@",connectionError);
            }
            
            //send completion
            success(jsonObj, newResp.statusCode, newResp);
            
            //log request completion
            if (LOGGING_ENABLED) {
                NSLog(@"\n------------------------\nRequest:%@\nStatus Code: %li\nMessage:%@\n------------------------", url ,(long)newResp.statusCode, jsonObj);
            }
            
            //decrease requests count
            [[[WFHttp sharedWFHttp]requestsInProgress] removeLastObject];
            [WFHttp handleNetworkIndicator];
            
        }];
        
        [WFHttp handleNetworkIndicator];
    }else{
        failure(@"No internet connection");
    }
}

#pragma mark - POST
+(void)POST:(NSString *)url optionalHTTPHeaders:(NSDictionary *)headers object:(id)object completion:(void (^)(id, NSInteger, NSHTTPURLResponse *))completion {
    [WFHttp updateRequest:url optionalHTTPHeaders:headers object:object httpMethod:@"POST" contentType:WFHTTPContentTypeJSON completion:completion];
}

+(void)POST:(NSString *)url optionalHTTPHeaders:(NSDictionary *)headers form:(id)form completion:(void (^)(id, NSInteger, NSHTTPURLResponse *))completion {
    [WFHttp updateRequest:url optionalHTTPHeaders:headers object:form httpMethod:@"POST" contentType:WFHTTPContentTypeMultipartForm completion:completion];
}

+(void)POSTToQueue:(NSString *)url optionalHTTPHeaders:(NSDictionary *)headers object:(id)object{
    
    NSMutableArray *requests = [[WFHttp sharedWFHttp]requests];
    
    //Init request
    NSMutableURLRequest *request = [NSMutableURLRequest
                                    requestWithURL:[NSURL URLWithString:url]];
    
    //Set headers
    [request setHTTPMethod:@"POST"];
    
    
    NSDictionary *parameters = NULL;
    if ([object isKindOfClass:[NSDictionary class]]) {
        parameters = object;
    }else{
        parameters = [WFHttp createObjectDictionaryFromObject:object];
        
    }
    
    NSData *userData = [NSJSONSerialization dataWithJSONObject:parameters options:NSJSONWritingPrettyPrinted error:nil];
    [request setHTTPBody:userData];
    
    //q to send later
    [requests addObject:request];
    
    //send all requests once we've hit the threshold
    int qThreshold = [[WFHttp sharedWFHttp]queueEmptyThreshold];
    if (requests.count >= qThreshold) {
        [WFHttp sendQueue];
    }
}


#pragma mark - PUT
+(void)PUT:(NSString *)url optionalHTTPHeaders:(NSDictionary *)headers form:(id)form completion:(void (^)(id, NSInteger, NSHTTPURLResponse *))completion {
    [WFHttp updateRequest:url optionalHTTPHeaders:headers object:form httpMethod:@"PUT" contentType:WFHTTPContentTypeMultipartForm completion:completion];
}

+(void)PUT:(NSString *)url optionalHTTPHeaders:(NSDictionary *)headers object:(id)object completion:(void (^)(id, NSInteger, NSHTTPURLResponse *))completion {
    [WFHttp updateRequest:url optionalHTTPHeaders:headers object:object httpMethod:@"PUT" contentType:WFHTTPContentTypeJSON completion:completion];
}


#pragma mark - POST/PUT root
+(void)updateRequest:(NSString *)url optionalHTTPHeaders:(NSDictionary *)headers object:(id)object httpMethod:(NSString *)method contentType:(WFHTTPContentType )contentType completion:(void (^)(id result, NSInteger statusCode, NSHTTPURLResponse *response))completion{
    
    if ([self internetReachable]) {
        
        //increase requests count
        [[[WFHttp sharedWFHttp]requestsInProgress] addObject:@""];
        
        //Init request
        NSMutableURLRequest *request = [NSMutableURLRequest
                                        requestWithURL:[NSURL URLWithString:url]];
        
        //Set headers
        [request setHTTPMethod:method];
        [WFHttp addHeaders:headers toRequest:request];
        
        //set request content according to what was requested
        switch (contentType) {
            case WFHTTPContentTypeJSON:
                [WFHttp formatRequestForJSON:request object:object];
                break;
                
            case WFHTTPContentTypeMultipartForm:
                [WFHttp formatRequestForMultipartForm:request object:object];
                break;
                
            default:
                break;
        }
        
        //print logs if needed
        if (LOGGING_ENABLED) {
            NSLog(@"\n\nWFHTTP-%@: %@",request.HTTPMethod ,url);
        }
        
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            
            //get the http headers
            NSHTTPURLResponse* newResp = (NSHTTPURLResponse*)response;
            NSString *contentType = [newResp allHeaderFields][@"Content-Type"];
            contentType = [contentType lowercaseString];
            
            //serialize if content type is JSON
            if ([WFHttp string:contentType contains:@"json"] && response) {
                response = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
            }
            
            if (connectionError) {
                NSLog(@"%@",connectionError);
            }
            
            if (LOGGING_ENABLED) {
                NSLog(@"\n------------------------\nRequest:%@\nStatus Code: %li\nMessage:%@\n------------------------", url ,(long)newResp.statusCode, response);
            }
            
            //send completion
            completion(response, newResp.statusCode, newResp);
            
            //decrease requests count
            [[[WFHttp sharedWFHttp]requestsInProgress] removeLastObject];
            [WFHttp handleNetworkIndicator];
            
        }];
        
        [WFHttp handleNetworkIndicator];
    }else{
        NSLog(@"No internet connection");
    }
}


@end






