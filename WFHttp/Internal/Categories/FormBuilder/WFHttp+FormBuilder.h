//
//  WFHttp+FormBuilder.h
//  Testee
//
//  Created by William Falcon on 6/14/15.
//  Copyright (c) 2015 William Falcon. All rights reserved.
//

#import "WFHttp.h"

@import UIKit;

@interface WFHttp (FormBuilder)

+ (void)formatRequestForMultipartForm:(NSMutableURLRequest *)request object:(NSDictionary *)parameters;
@end
