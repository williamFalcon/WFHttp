//
//  WFHttp+StringHelpers.m
//  Testee
//
//  Created by William Falcon on 9/1/15.
//  Copyright (c) 2015 William Falcon. All rights reserved.
//

#import "WFHttp+StringHelpers.h"

@implementation WFHttp (StringHelpers)

/*
 basic string contains method
 */
+(BOOL)string:(NSString *)original contains:(NSString *)string {
    NSRange range = [original rangeOfString:string];
    return (range.location != NSNotFound);
}

@end
