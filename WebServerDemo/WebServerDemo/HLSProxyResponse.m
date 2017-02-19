//
//  HLSProxyResponse.h
//
//  Created by Fei Wang on 2017/2/19.
//

#import "HLSProxyResponse.h"
#import "HLSProxyServer.h"

#import "NIDebuggingTools.h"

// 缓存逻辑
#import "HSLVideoCache.h"
#import "NSString+NSString_URLEndecode.h"

@interface HLSProxyResponse()
@property (nonatomic, copy) NSString* targetUrl;
@property (nonatomic, strong) NSString* cacheKey;
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
        
        self.keyFilter = ^(NSURL * _Nullable url){
            return SMDefaultCacheKeyFilter(url);
        };
        
        self.cacheKey = self.keyFilter([NSURL URLWithString:self.targetUrl]);
        
        [self detectCache];
    }
    return self;
}


- (void) detectCache {
    _data = [[HSLVideoCache sharedHlsCache] videoForKey: self.cacheKey];
    if (_data.length > 0) {
        self.contentLength = _data.length;
        
        if ([self.targetUrl hasSuffix:@".m3u8"]) {
            NSString* str = [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding];
            str = nil;
        }
    } else {
        _data = nil;
    }
    
}

- (void)onClosed:(BOOL)succeed {
    NIDPRINT(@"Succeed: %d", succeed);
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (aSelector == @selector(asyncReadDataWithCompletion:)) {
        BOOL ok = _data.length == 0;
        // NIDPRINT(@"asyncReadDataWithCompletion ok: %d", ok);
        return ok;
    } else {
        return [super respondsToSelector:aSelector];
    }
}


- (NSData*)readData:(NSError**)error {
    NIDASSERT(_data.length > 0);
    NIDPRINT(@"==> Cache Hit: %@", _targetUrl);
    NSData* data;
    if (_done) {
        data = [NSData data]; // 通过返回长度为0的数据表示数据处理完毕
    } else {
        data = _data;
        _done = YES;
    }
    return data;
}


- (void)asyncReadDataWithCompletion:(GCDWebServerBodyReaderCompletionBlock)completionBlockInner {
    
    NIDASSERT(_data.length == 0);
    
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
    

    
    NSData* data = [[HSLVideoCache sharedHlsCache] videoForKey: self.cacheKey];
    
    NIDPRINT(@"Target: %@, CacheKey: %@", _targetUrl, self.cacheKey);
    
    // 如果缓存没有数据，如何处理呢?
    if (data.length == 0) {
        
        
        NSURL* url = [NSURL URLWithString:_targetUrl];
        NIDPRINT(@"VideoURL: %@", url);
        
        data = [NSData dataWithContentsOfURL:url];
        
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
        
        [[HSLVideoCache sharedHlsCache] storeVideoData: data forKey:self.cacheKey];        
    }
    
    // 数据处理完毕
    completionBlockInner(data, nil);
}
@end

