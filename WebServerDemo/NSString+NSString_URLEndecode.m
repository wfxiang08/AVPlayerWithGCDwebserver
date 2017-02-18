//
//  NSString+NSString_URLEndecode.m
//  WebServerDemo
//
//  Created by Fei Wang on 2017/2/18.
//  Copyright © 2017年 奉强. All rights reserved.
//

#import "NSString+NSString_URLEndecode.h"

@implementation NSString (NSString_URLEndecode)

- (NSString *)URLDecode {
    return [self stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)URLEncode {
    return [self urlEncodeUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)urlEncodeUsingEncoding:(NSStringEncoding)encoding {
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
                                                                                 NULL,
                                                                                 (__bridge CFStringRef)self,
                                                                                 NULL,
                                                                                 (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                                                 CFStringConvertNSStringEncodingToEncoding(encoding)));
}
@end
