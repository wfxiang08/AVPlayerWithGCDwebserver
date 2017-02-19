//
//  HLSProxyResponse.h
//
//  Created by Fei Wang on 2017/2/19.
//

#import "HLSProxyResponse.h"
#import "HLSProxyServer.h"

#import "NIDebuggingTools.h"
#import "VideoCacheManager.h"

@interface HLSProxyResponse()
@property (nonatomic, copy) NSString* targetUrl;
@property (nonatomic, assign) BOOL done;
@end

@implementation HLSProxyResponse {
    NSData* _data;
    
}

//
// 返回ContentType:
//   m3u8 --> application/x-mpegURL
//   ts   --> video/MP2T
// 暂不考虑其他的格式的文件
//
+ (NSString *)getContentType:(NSString *)target {
    
    if ([target rangeOfString:@".ts"].length > 0) {
        return @"video/MP2T";
    } else {
        return @"application/x-mpegURL";
    }
}

- (instancetype)initWithTargetUrl:(NSString*)targetUrl
                       cacheTsNum:(int)tsNum {
    if (self  = [super init]) {
        self.contentType = [HLSProxyResponse getContentType: targetUrl]; // 这个很重要
        self.done = NO;
        self.targetUrl = targetUrl;
        
        [self detectCache];
    }
    return self;
}


- (void) detectCache {
//    //判断该段数据是否已经缓存了
//    if([VideoCacheManager videoFilePartIsInCache:videoURL filePart:fileName]) {
//        
//        //已经缓存了，直接返回本地数据
//        NSString *localHashPath = [VideoCacheManager getVideoFileCachePath:videoURL
//                                                                  filePart:fileName];
//        
//        
//        NIDPRINT(@"RequestPath: %@, CurrentThread: %@", localHashPath, [NSThread currentThread]);
//        
//        // 从本地读取数据，直接返回
//        NSData *responseData = [NSData dataWithContentsOfFile:localHashPath];
//        if (responseData != nil && responseData.length > 0) {
//            if ([fileName hasSuffix:@".m3u8"]) {
//                NSString* str = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
//                str = nil;
//            }
//            GCDWebServerDataResponse* response = [GCDWebServerDataResponse responseWithData:responseData
//                                                                                contentType:contentType];
//            completionBlock(response);
//            //有缓存，返回数据，结束本次
//            return;
//        }
//    }
}

- (void)onClosed:(BOOL)succeed {
    NIDPRINT(@"Succeed: %d", succeed);
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (aSelector == @selector(asyncReadDataWithCompletion:)) {
        return _data == nil;
    } else {
        return [super respondsToSelector:aSelector];
    }
}


- (NSData*)readData:(NSError**)error {
    NSData* data;
    if (_done) {
        data = [NSData data];
    } else {
        data = _data;
        _done = YES;
    }
    return data;
}


- (void)asyncReadDataWithCompletion:(GCDWebServerBodyReaderCompletionBlock)completionBlockInner {
    // 这里很关键: 当前的block应该有状态
    // 例如如果底层和网络结合起来，每次回调都应该能从网络新读取一些数据；然后再回调 completionBlockInner
    // 什么时候回调结束呢?
    //   网络数据读取完毕，只有返回[NSData data]
    if (_done) {
        completionBlockInner([NSData data], nil);
        return;
    } else {
        _done = YES;
    }
    
    NSString* videoURL = [HLSProxyServer getVideoPath: _targetUrl];
    NSString* fileName = _targetUrl.lastPathComponent;
    
    NIDPRINT(@"Target: %@", _targetUrl);
    NIDPRINT(@"FilePart: %@, VideoPart: %@", fileName, videoURL);
    
    NSData* data = nil;
    NSString* cacheUrl = [VideoCacheManager getVideoFileCachePath:videoURL
                                                         filePart:fileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:cacheUrl]) {
        data = [NSData dataWithContentsOfFile:cacheUrl];
    }
    
    if (!data || data.length == 0) {
        
        NIDPRINT(@"VideoURL: %@", _targetUrl);
        
        data = [NSData dataWithContentsOfURL:[NSURL URLWithString:_targetUrl]];
        
        if ([_targetUrl hasSuffix:@".m3u8"]) {
            // 如果是m3u8文件，则特殊处理
            NSString* m3u8FileData = [[NSString alloc] initWithData: data
                                                           encoding:NSUTF8StringEncoding];
            
            for (int i = 0; i < 76; i++) {
                NSString* pattern = [NSString stringWithFormat:@"seg%05d.ts", i];
                NSString* targetUrl = [NSString stringWithFormat:@"http://192.168.31.187:8000/02/hls-low/%@", pattern];
                
                NSString* newUrl = [[HLSProxyServer shareInstance] getLocalURL:targetUrl];
                m3u8FileData = [m3u8FileData stringByReplacingOccurrencesOfString:pattern
                                                                       withString:newUrl];
            }
            
            data = [m3u8FileData dataUsingEncoding:NSUTF8StringEncoding];
        }
        
        if (!(data != nil && data.length > 0)) {
            int k = 0;
        }
        [VideoCacheManager copyCacheFileToCacheDirectoryWithData:data
                                                    videoRealUrl:videoURL
                                                        filePart:fileName];
        
    }
    
    // 数据处理完毕
    completionBlockInner(data, nil);
}
@end

