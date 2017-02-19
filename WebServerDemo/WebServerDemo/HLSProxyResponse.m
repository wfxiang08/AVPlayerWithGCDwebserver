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
@property (nonatomic, assign) BOOL started;
@property (nonatomic, copy) NSString* targetUrl;
@end

@implementation HLSProxyResponse

+ (instancetype)responseWithContentType:(NSString*)contentType
                              targetUrl:(NSString*)targetUrl {
    
    HLSProxyResponse* p = [[[self class] alloc] init];
    if (p) {
        p.started = NO;
        p.targetUrl = targetUrl;
    }
    return p;
}


- (void)asyncReadDataWithCompletion:(GCDWebServerBodyReaderCompletionBlock)completionBlockInner {
    // 这里很关键: 当前的block应该有状态
    // 例如如果底层和网络结合起来，每次回调都应该能从网络新读取一些数据；然后再回调 completionBlockInner
    // 什么时候回调结束呢?
    //   网络数据读取完毕，只有返回[NSData data]
    if (_started) {
        completionBlockInner([NSData data], nil);
        return;
    } else {
        _started = YES;
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

