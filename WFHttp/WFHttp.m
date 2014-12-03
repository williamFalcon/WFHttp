//
//  WFHttp.m
//  WFHttp
//
//  Created by William Falcon on 3/20/14.
//  Copyright (c) 2014 William Falcon. All rights reserved.
//

#import "WFHttp.h"
#import "Reachability.h"
#import <objc/runtime.h>
@import UIKit;

BOOL LOGGING_ENABLED = true;
NSString *POLICY_KEY = @"WFHTTP cookie policy";

@interface WFHttp()

//Holds requests waiting to be sent. Acts as a queque
@property (nonatomic) NSMutableArray *requests;

//makeshift tracks requests so we can show the nav spinner
@property (nonatomic) NSMutableArray *requestsInProgress;

@end

@implementation WFHttp
@synthesize cookiePolicy = _cookiePolicy;

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

#pragma mark - Regular requests


+(void)GET:(NSString *)url optionalParameters:(NSDictionary *)parameters optionalHTTPHeaders:(NSDictionary *)headers completion:(void (^)(id, NSInteger, NSHTTPURLResponse *))completion{
    
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
            
            if (connectionError) {
                NSLog(@"%@",connectionError);
            }
            
            //send completion
            completion(jsonObj, newResp.statusCode, newResp);
            
            if (LOGGING_ENABLED) {
                NSLog(@"Status Code: %li\n", (long)newResp.statusCode);
            }
            
            //decrease requests count
            [[[WFHttp sharedWFHttp]requestsInProgress] removeLastObject];
            [WFHttp handleNetworkIndicator];
            
        }];
        [WFHttp handleNetworkIndicator];
    }else{
        NSLog(@"No internet connection");
    }
}

+(void)POST:(NSString *)url optionalHTTPHeaders:(NSDictionary *)headers object:(id)object completion:(void (^)(id, NSInteger, NSHTTPURLResponse *))completion {
    [WFHttp updateRequest:url optionalHTTPHeaders:headers object:object httpMethod:@"POST" completion:completion];
}

+(void)PUT:(NSString *)url optionalHTTPHeaders:(NSDictionary *)headers object:(id)object completion:(void (^)(id, NSInteger, NSHTTPURLResponse *))completion {
    [WFHttp updateRequest:url optionalHTTPHeaders:headers object:object httpMethod:@"PUT" completion:completion];
}

#pragma mark - Q requests
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

#pragma mark - Session management

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

#pragma mark - Utilities
+(void)updateRequest:(NSString *)url optionalHTTPHeaders:(NSDictionary *)headers object:(id)object httpMethod:(NSString *)method completion:(void (^)(id result, NSInteger statusCode, NSHTTPURLResponse *response))completion{
    if ([self internetReachable]) {
        
        //increase requests count
        [[[WFHttp sharedWFHttp]requestsInProgress] addObject:@""];
        
        //Init request
        NSMutableURLRequest *request = [NSMutableURLRequest
                                        requestWithURL:[NSURL URLWithString:url]];
        
        //Set headers
        [request setHTTPMethod:method];
        [WFHttp addHeaders:headers toRequest:request];
        
        NSDictionary *parameters = NULL;
        if ([object isKindOfClass:[NSDictionary class]]) {
            parameters = object;
        }else{
            parameters = [WFHttp createObjectDictionaryFromObject:object];
        }
        
        NSData *userData = [NSJSONSerialization dataWithJSONObject:parameters options:NSJSONWritingPrettyPrinted error:nil];
        
        [request setHTTPBody:userData];
        [request setValue:@"application/json" forHTTPHeaderField:@"content-type"];
        
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
                NSLog(@"Status Code: %li\n", (long)newResp.statusCode);
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

/*
 basic string contains method
 */
+(BOOL)string:(NSString *)original contains:(NSString *)string {
    NSRange range = [original rangeOfString:string];
    return (range.location != NSNotFound);
}

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

/*
 Creates a dictionary from any object.
 Uses introspection to pupulate the array based on the object attributes
 */
+(NSDictionary *)createObjectDictionaryFromObject:(id)object{
    
    @autoreleasepool {
        
        NSArray *allowed = @[@"@\"NSString\"", @"i", @"@\"NSNumber\""];
        NSArray *objects = @[];
        NSArray *relationships = @[@"@\"NSMutableArray\""];
        
        //Create result dict
        NSMutableDictionary *result = [[NSMutableDictionary alloc]init];
        
        //Number of fields
        unsigned int count =0;
        
        //Get all properties
        objc_property_t *properties = class_copyPropertyList([object class], &count);
        
        //Iterate over properties
        for (unsigned int i =0; i<count; i++) {
            
            //Get the property at that index
            objc_property_t property = properties[i];
            
            //Get the property name
            const char * name = property_getName(property);
            const char * type = property_copyAttributeValue(property, "T");
            
            //Cast const char to string
            NSString *pNameString = [NSString stringWithFormat:@"%s",name];
            NSString *typeString = [NSString stringWithFormat:@"%s",type];
            
            
            if ([allowed containsObject:typeString]) {
                
                //Set the value in the dictionary using the key
                [result setValue:[object valueForKey:pNameString] forKey:pNameString];
                
                //An object
            }else if ([objects containsObject:typeString]){
                NSDictionary *subObj = [self createObjectDictionaryFromObject:[object valueForKey:pNameString]];
                [result setValue:subObj forKey:pNameString];
                
                //If a relationship
            }else if ([relationships containsObject:typeString]){
                
                //Init empty array
                NSMutableArray *relationship = [[NSMutableArray alloc]init];
                
                //Get objects for that relationship
                NSMutableArray * items = [object valueForKey:pNameString];
                
                //Iterate over array objects
                for (id object in items) {
                    
                    //Parse object
                    NSDictionary * subObj = [self createObjectDictionaryFromObject:object];
                    
                    //Add to relationship
                    [relationship addObject:subObj];
                }
                
                //Put in result
                [result setValue:relationship forKey:pNameString];
                
            }
        }
        free(properties);
        
        //Return the dictionary
        return result;
    }
}

+ (void)addHeaders:(NSDictionary *)headers toRequest:(NSMutableURLRequest *)request {
    if (headers && request) {
        [headers enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [request setValue:key forHTTPHeaderField:obj];
        }];
    }
}


+(NSString *)parametrizedUrl:(NSString *)url fromParameters:(NSDictionary *)parameters {
    
    if (url && parameters) {
        NSMutableString *parametrizedUrl = [NSMutableString stringWithString:url];
        
        [parametrizedUrl appendString:@"?"];
        
        for (NSString *key in parameters.allKeys) {
            NSString *value = parameters[key];
            [parametrizedUrl appendString:[NSString stringWithFormat:@"%@=%@&",key,value]];
        }
        
        NSString *result = [parametrizedUrl substringToIndex:parametrizedUrl.length-1];
        result = [result stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

        return result;
    }else {
        return url;
    }
}

#pragma mark - Reachability

/*
 Use reachability to check internet connection. If any is available, return YES
 */
+ (BOOL)internetReachable{
    
    NetworkStatus netStatus = [[Reachability reachabilityForInternetConnection] currentReachabilityStatus];
    
    if (netStatus == NotReachable) {
        return NO;
    }else{
        return YES;
    }
}

#pragma mark - Instance methods
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

+ (void)setCookiePolicy:(NSHTTPCookieAcceptPolicy)cookiePolicy {
    
    [[WFHttp sharedWFHttp]setCookiePolicy:cookiePolicy];
    
    //update the policy
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]setCookieAcceptPolicy:cookiePolicy];
    [[NSUserDefaults standardUserDefaults]setInteger:cookiePolicy forKey:POLICY_KEY];
}

@end






