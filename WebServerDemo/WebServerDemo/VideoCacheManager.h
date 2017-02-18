//
//  VideoCacheFileManager.h
//  WebServerDemo
//
//  Created by 广州加减信息技术有限公司 on 16/2/18.
//  Copyright © 2016年 奉强. All rights reserved.
//

#import <Foundation/Foundation.h>

// 两层
//  视频目录 Video
//  视频分块文件 VideoFile
//
@interface VideoCacheManager : NSObject


// 确保videoURL对应的缓存目录存在
+ (void)ensureVideoCacheDirForUrl:(NSString *)videoRealUrl;

// 获取"视频文件"的本地缓存路径
+ (NSString *)getVideoFileCachePath:(NSString *)videoRealUrl
                           filePart:(NSString *)filePart;


+ (BOOL)videoFilePartIsInCache:(NSString *)videoRealUrl
                      filePart:(NSString *)filePart;



+ (BOOL)copyCacheFileToCacheDirectoryWithData:(NSData *)data
                                 videoRealUrl:(NSString *)videoRealUrl
                                     filePart:(NSString *)filePart;


@end
