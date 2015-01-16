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

static BOOL LOGGING_ENABLED = true;
static BOOL PRINT_POST_JSON_BEFORE_SENDING = true;
static NSString *MULTIPART_FORM_BOUNDARY = @"w3f7h8t9t0p";
static NSString *POLICY_KEY = @"WFHTTP cookie policy";

typedef NS_ENUM(int, WFHTTPContentType) {
    WFHTTPContentTypeJSON,
    WFHTTPContentTypeMultipartForm
};

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
                NSLog(@"\n------------------------\nRequest:%@\nStatus Code: %li\nMessage:%@\n------------------------", url ,(long)newResp.statusCode, jsonObj);
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
    [WFHttp updateRequest:url optionalHTTPHeaders:headers object:object httpMethod:@"POST" contentType:WFHTTPContentTypeJSON completion:completion];
}

+(void)PUT:(NSString *)url optionalHTTPHeaders:(NSDictionary *)headers form:(id)form completion:(void (^)(id, NSInteger, NSHTTPURLResponse *))completion {
    [WFHttp updateRequest:url optionalHTTPHeaders:headers object:form httpMethod:@"PUT" contentType:WFHTTPContentTypeMultipartForm completion:completion];
}

+(void)PUT:(NSString *)url optionalHTTPHeaders:(NSDictionary *)headers object:(id)object completion:(void (^)(id, NSInteger, NSHTTPURLResponse *))completion {
    [WFHttp updateRequest:url optionalHTTPHeaders:headers object:object httpMethod:@"PUT" contentType:WFHTTPContentTypeJSON completion:completion];
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
    
    //post reachability notification so listeners can respond if network changed
    [[NSNotificationCenter defaultCenter]postNotificationName:kReachabilityChangedNotification object:nil];
    
    if (netStatus == NotReachable) {
        return NO;
    }else{
        return YES;
    }
}

#pragma mark - Request formatting Utils

+ (void)formatRequestForJSON:(NSMutableURLRequest *)request object:(id)object {
    
    //convert obj to JSON
    NSDictionary *parameters = NULL;
    if ([object isKindOfClass:[NSDictionary class]]) {
        parameters = object;
    }else{
        parameters = [WFHttp createObjectDictionaryFromObject:object];
    }
    
    //create JSON
    NSData *userData = [NSJSONSerialization dataWithJSONObject:parameters options:NSJSONWritingPrettyPrinted error:nil];
    [request setHTTPBody:userData];
    [request setValue:@"application/json" forHTTPHeaderField:@"content-type"];
    
    //print JSON before post if requested
    if (PRINT_POST_JSON_BEFORE_SENDING) {
        NSString* jsonString = [[NSString alloc] initWithData:userData encoding:NSUTF8StringEncoding];
        NSLog(@"jsonString: %@", jsonString);
    }
}

+ (void)formatRequestForMultipartForm:(NSMutableURLRequest *)request object:(NSDictionary *)parameters {
    
    NSString *FileParamConstant = @"uploadFile";
    
    // set Content-Type in HTTP header
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", MULTIPART_FORM_BOUNDARY];
    [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    // post body
    NSMutableData *body = [NSMutableData data];
    
    // add params (all params are strings)
    for (NSString *param in parameters) {
        
        id value = parameters[param];
        
        //format all strings in the form
        if ([value isKindOfClass:[NSString class]]) {
            [body appendData:[[NSString stringWithFormat:@"--%@\r\n", MULTIPART_FORM_BOUNDARY] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", param] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"%@\r\n", value] dataUsingEncoding:NSUTF8StringEncoding]];
        }
        
        //format images in the form
        if ([value isKindOfClass:[UIImage class]]) {
            UIImage *imageToPost = value;
            
            // add image data
            NSData *imageData = UIImageJPEGRepresentation(imageToPost, 1.0);
            if (imageData) {
                NSString *imageName = param;
                [body appendData:[[NSString stringWithFormat:@"--%@\r\n", MULTIPART_FORM_BOUNDARY] dataUsingEncoding:NSUTF8StringEncoding]];
                [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", FileParamConstant, imageName] dataUsingEncoding:NSUTF8StringEncoding]];
                [body appendData:[@"Content-Type: image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
                [body appendData:imageData];
                [body appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
            }
            
            [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", MULTIPART_FORM_BOUNDARY] dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    
    // setting the body of the post to the reqeust
    [request setHTTPBody:body];
    
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






