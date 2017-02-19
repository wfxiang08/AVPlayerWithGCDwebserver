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
    // 删除“#”后面的部分，删除"?"后面的部分
    NSString* result = [url absoluteString];
    result = [result componentsSeparatedByString:@"#"][0];
    result = [result componentsSeparatedByString:@"?"][0];
    
    
    result = [result stringByReplacingOccurrencesOfString:@"/hls-high/" withString:@"/hls/"];
    result = [result stringByReplacingOccurrencesOfString:@"/hls-low/"  withString:@"/hls/"];

    if ([result hasSuffix:@".ts"]) {
        // 老版本m3u8文件不做缓存优化，因为playlist文件内容不一样
        // hls-360p/hls-360p00002.ts --> /hlsold/00002.ts
        result = [result stringByReplacingOccurrencesOfString:@"hls-360p" withString:@"hlsold"];
        result = [result stringByReplacingOccurrencesOfString:@"hls-480p" withString:@"hlsold"];
        result = [result stringByReplacingOccurrencesOfString:@"hls-720p" withString:@"hlsold"];
    }
    
    
    NIDPRINT(@"Url Hash: %@ --> %@", url, result);
    
    // TODO: 增加更多的限制
    return cachedFileNameForKey(result);
    
}
