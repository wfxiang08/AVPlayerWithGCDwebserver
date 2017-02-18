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

#define FirstPatrFileName   @"list.m3u8"

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
                                 NSString *requestPath = [request.path stringByReplacingOccurrencesOfString:@"/" withString:@""];
                                 NIDPRINT(@"RequestPath: %@", request.path);
                                 
                                 // 判断是否已经开始缓存了

            
                                 //判断该段数据是否已经缓存了
                                 if([VideoCacheManager videoFilePartIsInCache:self.videoRealUrlString filePart:requestPath]) {
                                     
                                     //已经缓存了，直接返回本地数据
                                     NSString *contentType = [self getContentType:requestPath];
                                     NSString *localHashPath = [VideoCacheManager getVideoFileCachePath:self.videoRealUrlString
                                                                                                   filePart:requestPath];
            
                                     
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
                                NSString *videoUrlString = [NSString stringWithFormat:@"%@/%@", self.videoRealUrlString, requestPath];
                                NSURL *videoUrl = [NSURL URLWithString:videoUrlString];
                                NSString *contentType = [self getContentType:requestPath];
                                
                                // 直接下载
                                GCDWebServerStreamedResponse *responseStream =
                                    [GCDWebServerStreamedResponse responseWithContentType:contentType
                                                                         asyncStreamBlock:^(GCDWebServerBodyReaderCompletionBlock completionBlock) {
                                    
                                                                             NSData *data;

                                                                             if ([VideoCacheManager getVideoFileCachePath:self.videoRealUrlString
                                                                                                                     filePart:requestPath]) {
                                                                                 data = [NSData data];
                                                                             } else {
                                                                                 data = [NSData dataWithContentsOfURL:videoUrl];
                                                                                 [VideoCacheManager copyCacheFileToCacheDirectoryWithData:data
                                                                                                                                 videoRealUrl:self.videoRealUrlString
                                                                                                                                     filePart:requestPath];

                                                                             }
                                    
                                                                             completionBlock(data, nil);
                                                                         }];
                                
                                 completionBlock(responseStream);
                            }];
                            
    
    [self.webServer start];
        
    
    //设置服务器的本地url
    self.videoLocalUrlString = self.webServer.serverURL.relativeString;
}

- (NSString *)getUrlStringWithRealUrlString:(NSString *)realUrlString {
    
    self.videoRealUrlString = [realUrlString stringByReplacingOccurrencesOfString:@"/list.m3u8" withString:@""];
    
    NSString *urlStr = [NSString stringWithFormat:@"%@",self.videoLocalUrlString];
    
    urlStr = [NSString stringWithFormat:@"%@%@?realUrlStr=%@", urlStr, FirstPatrFileName, realUrlString];
    
    return urlStr;
}

//
// 返回ContentType:
//   m3u8 --> application/x-mpegURL
//   ts   --> video/MP2T
// 暂不考虑其他的格式的文件
//
- (NSString *)getContentType:(NSString *)partName {
    
    NSString *contenTypeString = [partName isEqualToString:FirstPatrFileName] ? @"application/x-mpegURL" : @"video/MP2T";
    
    return contenTypeString;
}

- (void)stopWebSever {
    [self.webServer stop];
}

@end
