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
@property (nonatomic, assign) int cacheTsNum;
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
        self.cacheTsNum = tsNum;
        
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


- (void)onClosed:(BOOL)succeed {
    NIDPRINT(@"Succeed: %d", succeed);
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
        // 这个地方比较关键
        NSURL* url = [NSURL URLWithString:_targetUrl];
        NIDPRINT(@"Cache Miss, Get by URL: %@", url);
        
        // TODO: 优化
        data = [NSData dataWithContentsOfURL:url];
        
        if (data.length > 0 && ![_targetUrl hasSuffix:@".ts"]) {
            data = [self processM3U8:data baseUrl:url maxProxyLine:self.cacheTsNum];
            
            NSString* dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            dataStr = nil;
        }
        
        // 缓存数据
        if (data.length > 0) {
            [[HSLVideoCache sharedHlsCache] storeVideoData: data forKey:self.cacheKey completion:nil];
        }
    }
    
    // 数据处理完毕
    completionBlockInner(data, nil);
}

- (NSData*) processM3U8:(NSData*)data baseUrl:(NSURL*)baseUrl maxProxyLine:(int)maxLine {
    // http://stackoverflow.com/questions/11218318/reading-file-line-by-line-in-ios-sdk
    NSString* dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray<NSString*>* lines = [dataStr componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    NSData* lineData = [@"\n" dataUsingEncoding: NSUTF8StringEncoding];
    NSMutableData* result = [[NSMutableData alloc] init];
    
    
    int tsCount = 0;
    for (int i = 0; i < lines.count; i++) {
        NSString* line = lines[i];
        if ([line hasSuffix:@".ts"]) {
            // 变成绝对的URL
            NSURL* lineURL = [NSURL URLWithString:line relativeToURL:baseUrl];
            if (tsCount < maxLine) {
                line = [[HLSProxyServer shareInstance] getLocalURL:lineURL.absoluteString withHost:NO];
                // tsCount++;
                // 全部都走代理，可以对多码率的视频做cache
            } else {
                line = [lineURL absoluteString];
            }
        } else if ([line hasSuffix:@".m3u8"]) {
            // 变成绝对的URL
            NSURL* lineURL = [NSURL URLWithString:line relativeToURL:baseUrl];
            line = [[HLSProxyServer shareInstance] getLocalURL:lineURL.absoluteString withHost:NO];
        }
    
        [result appendData: [line dataUsingEncoding:NSUTF8StringEncoding]];
        [result appendData:lineData];
    }
    return result;
}

@end

