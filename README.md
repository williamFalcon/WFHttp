WFHttp
======

Simple, lightweight HTTP class for iOS.

SAMPLE USE
=================================
1. GET
```objective-c
        [WFHttp GET:@"http://myUrl.com" completion:^(id result) {
        
            //do stuff with my results
        }];
```  
2. POST
```objective-c
        [WFHttp POST:@"http://myUrl.com" object:myObject completion:^(id result) {
            
            //do stuff with my results
        }];
```   

METHODS
=================================
- **`+(id)sharedWFHttp;`**   
 Singleton instance to access manager from anywhere

- **`+(void)GET:(NSString*)url completion:(void(^)(id result))completion`**   
 Basic GET request. Results return in the completion block


- **`+(void)POST:(NSString*)url object:(id)object completion:(void(^)(id result))completion`**   
 Basic POST request. Results return in the completion block
 Object can be anything (array, dictionary, NSObject, and more)


- **`+(void)POSTToQueue:(NSString *)url object:(id)object`**   
 Create a post request but instead of sending immediately, it adds to a queue to be sent after
 the threshold specified


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
None

