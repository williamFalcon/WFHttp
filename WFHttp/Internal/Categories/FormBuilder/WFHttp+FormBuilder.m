//
//  WFHttp+FormBuilder.m
//  Testee
//
//  Created by William Falcon on 6/14/15.
//  Copyright (c) 2015 William Falcon. All rights reserved.
//

#import "WFHttp+FormBuilder.h"

static NSString *MULTIPART_FORM_BOUNDARY = @"w3f7h8t9t0p";
@implementation WFHttp (FormBuilder)

+ (void)formatRequestForMultipartForm:(NSMutableURLRequest *)request object:(NSDictionary *)parameters {
    
    NSMutableData* body = [NSMutableData data];
    
    //set header boundary
    [WFHttp insertHeaderBoundary:MULTIPART_FORM_BOUNDARY toRequest:request];
    NSData *boundaryData = [[NSString stringWithFormat:@"--%@\r\n", MULTIPART_FORM_BOUNDARY] dataUsingEncoding:NSUTF8StringEncoding];
    
    //insert parameters
    [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [body appendData:boundaryData];
        
        // Any values that are data are a file
        if ([obj isKindOfClass:[NSData class]]) {
            [WFHttp insertFile:obj fileName:key intoFormBody:body];
        }
        
        else {
            // Regular param
            [body appendData: [[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n%@\r\n", key, obj] dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }];
    
    //set ending params
    [WFHttp insertFooterBoundary:MULTIPART_FORM_BOUNDARY toBody:body request:request];
    [request setHTTPBody:body];
}

///inserts the form header
+ (void)insertHeaderBoundary:(NSString *)boundary toRequest:(NSMutableURLRequest *)request {
    
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];
}

///inserts the form footer
+ (void)insertFooterBoundary:(NSString *)boundary toBody:(NSMutableData *)body request:(NSMutableURLRequest *)request {
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[body length]] forHTTPHeaderField:@"Content-Length"];
}

///Inserts an image into the body
+ (void)insertFile:(NSData *)data fileName:(NSString *)fileName intoFormBody:(NSMutableData *)body {
    
    // File upload
    [body appendData: [[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n\r\n", fileName, fileName] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData: data];
    [body appendData: [@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
}

@end
