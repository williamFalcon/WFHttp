//
//  WFHttp+Parsing.m
//  Testee
//
//  Created by William Falcon on 9/1/15.
//  Copyright (c) 2015 William Falcon. All rights reserved.
//

#import "WFHttp+Parsing.h"
#import <objc/runtime.h>

@implementation WFHttp (Parsing)

#pragma mark - Request formatting Utils

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

#pragma mark - JSON Parsers
+ (NSDictionary *)createObjectDictionaryFromObject:(id)object{
    
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

@end
