//
//  WFHttp.m
//  WFHttp
//
//  Created by William Falcon on 3/20/14.
//  Copyright (c) 2014 William Falcon. All rights reserved.
//

#import "WFHttp.h"
#import <objc/runtime.h>

@interface WFHttp()

//Holds requests waiting to be sent. Acts as a queque
@property (nonatomic) NSMutableArray *requests;
@end

@implementation WFHttp

#pragma mark - Singleton
+(id)sharedWFHttp{
    
    static id WFHttp = nil;
    
    if (!WFHttp) {
        WFHttp = [[self alloc]init];
    }
    
    return WFHttp;
}

-(id)init{
    
    self = [super init];
    self.requests = [NSMutableArray new];
    self.queueEmptyThreshold = 4;
    
    //subscribe to resignActive so we can send all requests that have been enqueued
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(purgeQueue) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(purgeQueue) name:UIApplicationWillTerminateNotification object:nil];
    
    return self;
}

#pragma mark - Regular requests
+(void)GET:(NSString *)url completion:(void (^)(id))completion{
    
    //Init request
    NSMutableURLRequest *request = [NSMutableURLRequest
                                    requestWithURL:[NSURL URLWithString:url]];
    
    //Set headers
    [request setHTTPMethod:@"GET"];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        
        //get the http headers
        NSHTTPURLResponse* newResp = (NSHTTPURLResponse*)response;
        NSString *contentType = [newResp allHeaderFields][@"Content-Type"];
        contentType = [contentType lowercaseString];
        
        //serialize if content type is JSON
        if ([WFHttp string:contentType contains:@"json"]) {
            response = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
        }
        
        if (connectionError) {
            NSLog(@"%@",connectionError);
        }
        
        //send completion
        completion(response);
        
    }];
}

+(void)POST:(NSString *)url object:(id)object completion:(void (^)(id))completion{
    
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
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        
        //get the http headers
        NSHTTPURLResponse* newResp = (NSHTTPURLResponse*)response;
        NSString *contentType = [newResp allHeaderFields][@"Content-Type"];
        contentType = [contentType lowercaseString];
        
        //serialize if content type is JSON
        if ([WFHttp string:contentType contains:@"json"]) {
            response = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
        }
        
        if (connectionError) {
            NSLog(@"%@",connectionError);
        }
        
        //send completion
        completion(response);
    }];
}
#pragma mark - Q requests
+(void)POSTToQueue:(NSString *)url object:(id)object{
    
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
    
    NSMutableArray *requests = [[WFHttp sharedWFHttp]requests];
    for (NSMutableURLRequest *request in requests) {
        
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            
            //get the http headers
            NSHTTPURLResponse* newResp = (NSHTTPURLResponse*)response;
            NSString *contentType = [newResp allHeaderFields][@"Content-Type"];
            contentType = [contentType lowercaseString];
            
            //serialize if content type is JSON
            if ([WFHttp string:contentType contains:@"json"]) {
                response = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
            }
            
            if (connectionError) {
                NSLog(@"%@",connectionError);
            }
        }];
    }
    
    //clear the q
    [requests removeAllObjects];
}

+(int)postRequestsInQueue{
    return [[[WFHttp sharedWFHttp]requests]count];
}

#pragma mark - Helpers

/*
 basic string contains method
 */
+(BOOL)string:(NSString *)original contains:(NSString *)string {
    NSRange range = [original rangeOfString:string];
    return (range.location != NSNotFound);
}

/*
 Creates a dictionary from any object.
 Uses introspection to pupulate the array based on the object attributes
 */
+(NSDictionary *)createObjectDictionaryFromObject:(id)object{
    
    @autoreleasepool {
        
        NSArray *allowed = @[@"@\"NSString\"", @"i", @"@\"NSNumber\""];
        NSArray *objects = @[@"@\"Device\"", @"@\"User\"", @"@\"Ingredient\"", @"@\"Recipe\"", @"@\"GroceryList\"", @"@\"Event\"", @"@\"Follow\"", @"@\"Rating\"", @"@\"GroceryListItem\"", @"@\"Feed\"", @"@\"Device\""];
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
@end






