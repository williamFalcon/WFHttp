WFHttp
======

Simple, lightweight HTTP class for iOS.

SAMPLE USE
=================================
1. GET
```objective-c
        [WFHttp GET:@"http://myUrl.com" optionalParameters:nil optionalHTTPHeaders:nil completion:^(id result, NSInteger statusCode, NSHTTPURLResponse *response) {
         	
         	//do stuff with my results
    	}];
```  
2. POST
```objective-c
		[WFHttp POST:@"http://myUrl.com" optionalHTTPHeaders:nil object:myObject completion:^(id result, NSInteger statusCode, NSHTTPURLResponse *response) {
            
            //do stuff with my results
    	}];
```   

3. PUT (sending an image)
```objective-c
		UIImage *selfie = [...]
		NSDictionary *body = @{@"user_id":[User currentUser].id, @"mySelfie":selfie};

		[WFHttp PUT:@"http://myUrl.com" optionalHTTPHeaders:nil form:body completion:^(id result, NSInteger statusCode, NSHTTPURLResponse *response) {
         	//do stuff with my results
    	}];
```   

METHODS
=================================
- **`+(id)sharedWFHttp;`**   
 Singleton instance to access manager from anywhere

- **`+(void)GET:(NSString*)url optionalParameters:(NSDictionary *)parameters optionalHTTPHeaders:(NSDictionary *)headers completion:(void(^)(id result, NSInteger statusCode, NSHTTPURLResponse *response))completion`**   
 Basic GET request. Results return in the completion block


- **`+(void)POST:(NSString*)url optionalHTTPHeaders:(NSDictionary *)headers object:(id)object completion:(void(^)(id result, NSInteger statusCode, NSHTTPURLResponse *response))completion`**   
 Basic POST request. Results return in the completion block.   
 Object can be anything (array, dictionary, NSObject, and more).   

- **`+ (void)PUT:(NSString*)url optionalHTTPHeaders:(NSDictionary *)headers form:(id)form completion:(void(^)(id result, NSInteger statusCode, NSHTTPURLResponse *response))completion`**   
 Basic PUT request. Results return in the completion block.   
 Object is an NSDictionary that represents a form.    
 Adding an image to the dictionary results in sending the image.   
 Using id as type to be compatible with swift.   

- **`+(void)PUT:(NSString*)url optionalHTTPHeaders:(NSDictionary *)headers object:(id)object completion:(void(^)(id result, NSInteger statusCode, NSHTTPURLResponse *response))completion`**   
 Basic PUT request. Results return in the completion block.   
 Object can be anything (array, dictionary, NSObject, and more).   

- **`+(void)POSTToQueue:(NSString *)url object:(id)object`**   
 Create a post request but instead of sending immediately, it adds to a queue to be sent after.   
 the threshold specified.   


- **`+(void)sendQueue`**   
Sends all enqueued requests


- **`+(int)postRequestsInQueue`**   
 Returns the count of requests waiting to be sent


- **`-(void)purgeQueue`**   
 Sends all enqueued requests
 Uses a slightly different implementation to support background mode once
 app has exited

FEATURES
=================================

Http class wired to perform:

1. GET
2. POST
3. Batch POST requests

BUILT IN DEPENDENCIES
=================================
[Reachability](https://developer.apple.com/Library/ios/samplecode/Reachability/Introduction/Intro.html)

