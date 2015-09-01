//
//  WFHttp+StringHelpers.h
//  Testee
//
//  Created by William Falcon on 9/1/15.
//  Copyright (c) 2015 William Falcon. All rights reserved.
//

#import "WFHttp.h"

@interface WFHttp (StringHelpers)

+(BOOL)string:(NSString *)original contains:(NSString *)string;

@end
