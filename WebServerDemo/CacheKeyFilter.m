//
//  CacheKeyFilter.m
//
//  Created by Fei Wang on 2017/2/19.
//

#import "CacheKeyFilter.h"
#import <CommonCrypto/CommonDigest.h>
#import "NIDebuggingTools.h"

NSString * cachedFileNameForKey(NSString *key) {
    const char *str = key.UTF8String;
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15],
                          [key.pathExtension isEqualToString:@""] ? @"" : [NSString stringWithFormat:@".%@", key.pathExtension]];
    
    return filename;
}

NSString * _Nullable SMDefaultCacheKeyFilter(NSURL * _Nullable url) {
    NSString* result = url.path;
    
    NIDPRINT(@"UrlPath: %@", result);
    
    // TODO: 增加更多的限制
    return cachedFileNameForKey(result);
    
}
