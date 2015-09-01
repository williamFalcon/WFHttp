//
//  WFHttp+Parsing.h
//  Testee
//
//  Created by William Falcon on 9/1/15.
//  Copyright (c) 2015 William Falcon. All rights reserved.
//

#import "WFHttp.h"

@interface WFHttp (Parsing)

/**
Turns an objective C object into a dictionary
 
 @param id - Any Obj-C object
 @return NSDictionary - Dictionary representation of object
 */
+ (NSDictionary *)createObjectDictionaryFromObject:(id)object;


+ (void)formatRequestForJSON:(NSMutableURLRequest *)request object:(id)object;

+ (void)addHeaders:(NSDictionary *)headers toRequest:(NSMutableURLRequest *)request;

+ (NSString *)parametrizedUrl:(NSString *)url fromParameters:(NSDictionary *)parameters;

@end
