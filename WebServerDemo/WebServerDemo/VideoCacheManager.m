//
//  VideoCacheFileManager.m
//  WebServerDemo
//
//  Created by 广州加减信息技术有限公司 on 16/2/18.
//  Copyright © 2016年 奉强. All rights reserved.
//

#import "VideoCacheManager.h"
#import <CommonCrypto/CommonDigest.h>
#import "NIDebuggingTools.h"

@implementation VideoCacheManager


/**
 *  获取视频缓存文件
 *
 *  @param videoRealUrl 视频真实网络地址: TODO：这个需要特别处理
 *  @param filePart     要取的视屏文件段，分段规则如下：1、videoCache.m3u8   2、video_000.ts    3、video_001.ts...
 *
 *  @return 缓存文件的路径
 */
+ (NSString *)getVideoFileCachePath:(NSString *)videoRealUrl
                                       filePart:(NSString *)filePart {
    // 获取文件夹目录路径
    NSString *retStr = [self getVideoCacheDirFromUrl:videoRealUrl];
    
    // 目录 + filePart
    retStr = [retStr stringByAppendingPathComponent:filePart];
    
    return retStr;
}


// "视频地址" --> 视频缓存文件夹
//  缓存格式:
//       video_dir/playlist.m3u8
//       video_dir/seg000.ts
//       video_dir/seg001.ts
//       video_dir/seg002.ts
//
+ (BOOL)videoFilePartIsInCache:(NSString *)videoRealUrl
                      filePart:(NSString *)filePart {
    
    // 缓存文件目录
    NSString *fileHashPath = [self getVideoFileCachePath:videoRealUrl
                                                filePart:filePart];
    // 文件是否存在
    return [[NSFileManager defaultManager] fileExistsAtPath:fileHashPath];
}

/**
 *  根据视频真实地址，判断视频文件是否已经开始缓存（即使只缓存一个文件也返回真）
 *
 *  @param videoRealUrl 视频的真实网络地址
 *
 *  @return 是否已经缓存了
 */
+ (void)ensureVideoCacheDirForUrl:(NSString *)videoRealUrl {
    
    NSString *videoDir = [self getVideoCacheDirFromUrl:videoRealUrl];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:videoDir]) {
        NIDPRINT(@"Create Video Cache Dir: %@", videoDir);

        [fileManager createDirectoryAtPath:videoDir
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:nil];
    }
}

//
// 获取沙盒中Liberary/cache目录路径
//
+ (NSString *)getSandboxCacheDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachesDir = [paths objectAtIndex:0];
    return cachesDir;
}

// "视频地址" --> 视频缓存文件夹
//  缓存格式:
//       video_dir/playlist.m3u8
//       video_dir/seg000.ts
//       video_dir/seg001.ts
//       video_dir/seg002.ts
//
+ (NSString *)getVideoCacheDirFromUrl:(NSString *)videoRealUrl {
    NSString *retStr = [self getSandboxCacheDirectory];
    retStr = [retStr stringByAppendingPathComponent:@"SMVideoCache"];
    retStr = [retStr stringByAppendingPathComponent:[self md5HexDigest:videoRealUrl]];
    
    return retStr;
}


//
// 把下载下来的缓存文件保存到缓存文件夹
//
+ (BOOL)copyCacheFileToCacheDirectoryWithData:(NSData *)data
                                 videoRealUrl:(NSString *)videoRealUrl
                                     filePart:(NSString *)filePart {

    [self ensureVideoCacheDirForUrl:videoRealUrl];

    NSString *newFilePathString = [self getVideoFileCachePath:videoRealUrl filePart:filePart];
    
    NSURL *newFilePathUrl = [NSURL fileURLWithPath:newFilePathString];
    
    NIDPRINT(@"Save Cache To File: %@", newFilePathUrl);
    
    if ([[NSFileManager defaultManager] fileExistsAtPath: newFilePathString]) {
        [[NSFileManager defaultManager] removeItemAtPath: newFilePathString error: nil];
    }
    
    BOOL ret = [data writeToURL:newFilePathUrl atomically:YES];
    
    if (!ret) {
        NSLog(@"文件复制错误");
    }
    
    return ret;
}

// 根据传入字符串  进行MD5加密
+ (NSString *)md5HexDigest:(NSString *)url {
    const char *original_str = [url UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(original_str, (CC_LONG)strlen(original_str), result);
    NSMutableString *hash = [NSMutableString string];
    for (int i = 0; i < 16; i++) {
        [hash appendFormat:@"%02X", result[i]];
    }
    return [hash lowercaseString];
}

@end
