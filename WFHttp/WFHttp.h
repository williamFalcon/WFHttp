//
//  WFHttp.h
//  WFHttp
//
//  Created by William Falcon on 3/20/14.
//  Copyright (c) 2014 William Falcon. All rights reserved.
//

#import <Foundation/Foundation.h>


static BOOL LOGGING_ENABLED = true;
static BOOL PRINT_POST_JSON_BEFORE_SENDING = true;

typedef NS_ENUM(int, WFHTTPContentType) {
    WFHTTPContentTypeJSON,
    WFHTTPContentTypeMultipartForm
};


@interface WFHttp : NSObject

//Holds requests waiting to be sent. Acts as a queque
@property (nonatomic) NSMutableArray *requests;

//makeshift tracks requests so we can show the nav spinner
@property (nonatomic) NSMutableArray *requestsInProgress;

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


#pragma mark - GET
/*
 Basic GET request. Results return in the completion block
 */
+(void)GET:(NSString*)url optionalParameters:(NSDictionary *)parameters optionalHTTPHeaders:(NSDictionary *)headers onSuccess:(void(^)(id result, NSInteger statusCode, NSHTTPURLResponse *response))success onFailure:(void(^)(NSString *error))failure;

#pragma mark - POST
/*
 Basic POST request. Results return in the completion block
 Object can be anything (array, dictionary, NSObject, and more)
 */
+(void)POST:(NSString*)url optionalHTTPHeaders:(NSDictionary *)headers object:(id)object completion:(void(^)(id result, NSInteger statusCode, NSHTTPURLResponse *response))completion;

+(void)POST:(NSString *)url optionalHTTPHeaders:(NSDictionary *)headers form:(id)form completion:(void (^)(id, NSInteger, NSHTTPURLResponse *))completion;

/*
 Create a post request but instead of sending immediately, it adds to a queue to be sent after
 the threshold specified
 */
+(void)POSTToQueue:(NSString *)url optionalHTTPHeaders:(NSDictionary *)headers object:(id)object;


#pragma mark - PUT
/*
 Basic POST request. Used for multipart form. To post image, add image to form dictionary
 
 Ex: To post image, add an image parameter to the dictionary
 */
+ (void)PUT:(NSString*)url optionalHTTPHeaders:(NSDictionary *)headers form:(id)form completion:(void(^)(id result, NSInteger statusCode, NSHTTPURLResponse *response))completion;


/*
 Basic PUT request. Results return in the completion block
 Object can be anything (array, dictionary, NSObject, and more)
 */
+(void)PUT:(NSString*)url optionalHTTPHeaders:(NSDictionary *)headers object:(id)object completion:(void(^)(id result, NSInteger statusCode, NSHTTPURLResponse *response))completion;


@end






