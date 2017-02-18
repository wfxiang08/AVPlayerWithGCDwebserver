//
//  VideoCacheTool.m
//  WebServerDemo
//
//  Created by 广州加减信息技术有限公司 on 16/2/18.
//  Copyright © 2016年 奉强. All rights reserved.
//

#import "VideoCacheTool.h"
#import "GCDWebServer.h"
#import "GCDWebServerPrivate.h"
#import "VideoCacheManager.h"
#import "NIDebuggingTools.h"
#import "NSString+NSString_URLEndecode.h"

#define FirstPatrFileName   @"playlist.m3u8"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface VideoCacheTool ()

@property (nonatomic, strong) GCDWebServer *webServer;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation VideoCacheTool

- (instancetype)init {
    if (self = [super init]) {
        // 初始化WebServer
        [self initWebServer];
    }
    
    return self;
}

#pragma mark 初始化本地web服务器
- (void)initWebServer {
    NIDPRINTMETHODNAME();

    // 初始化本地web服务器
    self.webServer = [[GCDWebServer alloc] init];
    
    // 添加一个get响应
    // 如何代理请求呢?
    // 局限于：m3u8
    // 重点: 设置webServer的callback
    @weakify(self)
    [self.webServer addDefaultHandlerForMethod:@"GET"
                                  requestClass:[GCDWebServerRequest class]
                             asyncProcessBlock:^(GCDWebServerRequest *request, GCDWebServerCompletionBlock completionBlock) {
                                 
                                 @strongify(self)
                                 
                                 // 请求的段名
                                 NSString* target = request.query[@"target"];
                                 
                                 NIDPRINT(@"RequestPath: %@", request.path);
                                 NIDPRINT(@"Target: %@", target);

                                 
                                 // 判断是否已经开始缓存了
                                 
                                 NSString* videoURL = [self getVideoPath: target];
                                 NSString* contentType = [self getContentType:target];
                                 NSString* fileName = target.lastPathComponent;

                                 //判断该段数据是否已经缓存了
                                 if([VideoCacheManager videoFilePartIsInCache:videoURL filePart:fileName]) {
                                     
                                     //已经缓存了，直接返回本地数据
                                     NSString *localHashPath = [VideoCacheManager getVideoFileCachePath:videoURL
                                                                                               filePart:fileName];
            
                                     
                                     NIDPRINT(@"RequestPath: %@, CurrentThread: %@", localHashPath, [NSThread currentThread]);
                                     
                                     // 从本地读取数据，直接返回
                                     NSData *responseData = [NSData dataWithContentsOfFile:localHashPath];
                                     GCDWebServerDataResponse* response = [GCDWebServerDataResponse responseWithData:responseData
                                                                                                         contentType:contentType];
            
                                     completionBlock(response);
            
                                     //有缓存，返回数据，结束本次
                                     return;
                                 }
                                
        
                                // 没有缓存
                                // 1、先请求数据
                                // 直接下载
                                GCDWebServerStreamedResponse *responseStream =
                                    [GCDWebServerStreamedResponse responseWithContentType:contentType
                                                                         asyncStreamBlock:^(GCDWebServerBodyReaderCompletionBlock completionBlock) {
                                    
                                                                             NIDPRINT(@"Target: %@", target);
                                                                             NIDPRINT(@"FilePart: %@, VideoPart: %@", fileName, [self getVideoPath: target]);
                                                                             
                                                                             NSData* data = nil;
                                                                             NSString* cacheUrl = [VideoCacheManager getVideoFileCachePath:[self getVideoPath: target]
                                                                                                                                  filePart:fileName];
                                                                             if ([[NSFileManager defaultManager] fileExistsAtPath:cacheUrl]) {
                                                                                 data = [NSData dataWithContentsOfFile:cacheUrl];
                                                                             }
                                                                             
                                                                             if (!data || data.length == 0) {
                                                                             
                                                                                 NIDPRINT(@"VideoURL: %@", target);
                                                                                 
                                                                                 data = [NSData dataWithContentsOfURL:[NSURL URLWithString:target]];
                                                                                 if ([target hasSuffix:@".m3u8"]) {
                                                                                     // 如果是m3u8文件，则特殊处理
                                                                                     NSString* str = [[NSString alloc] initWithData: data encoding:NSUTF8StringEncoding];

                                                                                     for (int i = 0; i < 73; i++) {
                                                                                         NSString* pattern = [NSString stringWithFormat:@"seg%05d.ts", i];
                                                                                         NSString* targetUrl = [NSString stringWithFormat:@"http://192.168.31.187:8000/02/hls-low/%@", pattern];
                                                                                         
                                                                                         NSString* newUrl = [self getLocalURL:targetUrl];
                                                                                         str = [str stringByReplacingOccurrencesOfString:pattern withString:newUrl];
                                                                                     }
                                                                                     
                                                                                     data = [str dataUsingEncoding:NSUTF8StringEncoding];
                                                                                 }
                                                                                 
                                                                                 if (!(data != nil && data.length > 0)) {
                                                                                     int i = 0;
                                                                                 }
                                                                                 [VideoCacheManager copyCacheFileToCacheDirectoryWithData:data
                                                                                                                             videoRealUrl:[self getVideoPath: target]
                                                                                                                                 filePart:target.lastPathComponent];

                                                                             }
                                                                             
                                                                             // 数据处理完毕
                                                                             completionBlock(data, nil);
                                                                         }];
                                
                                 completionBlock(responseStream);
                            }];
                            
    
    [self.webServer start];
        
    
    //设置服务器的本地url
    self.localHttpHost = self.webServer.serverURL.relativeString;
}

- (NSString*) getVideoPath:(NSString*)m3u8FileUrl {

    NSRange range = [m3u8FileUrl rangeOfString:@"/" options:NSBackwardsSearch];
    NSString* result = [m3u8FileUrl substringToIndex: range.location];
    
    NIDPRINT(@"VideoPath: %@ <-- %@", result, m3u8FileUrl);
    return result;
}

- (NSString *)getLocalURL:(NSString *)realUrlString {
    
    NSString *urlStr = [NSString stringWithFormat:@"%@video?target=%@",
                        self.localHttpHost, [realUrlString URLEncode]];
    
    return urlStr;
}



//
// 返回ContentType:
//   m3u8 --> application/x-mpegURL
//   ts   --> video/MP2T
// 暂不考虑其他的格式的文件
//
- (NSString *)getContentType:(NSString *)target {
    
    if ([target rangeOfString:@".ts"].length > 0) {
        return @"video/MP2T";
    } else {
        return @"application/x-mpegURL";
    }
}

- (void)stopWebSever {
    [self.webServer stop];
}

@end
