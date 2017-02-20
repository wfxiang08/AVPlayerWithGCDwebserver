//
//  HLSProxyResponse.h
//
//  Created by Fei Wang on 2017/2/19.
//

#import "HLSProxyResponse.h"
#import "HLSProxyServer.h"
#import "HLSDownloader.h"

#import "NIDebuggingTools.h"

// 缓存逻辑
#import "HSLVideoCache.h"
#import "NSString+NSString_URLEndecode.h"

@interface HLSProxyResponse()
@property (nonatomic, copy) NSString* targetUrl;
@property (nonatomic, strong) NSString* cacheKey;
@property (nonatomic, assign) BOOL done;
@property (nonatomic, assign) BOOL downloadFinished;
@property (nonatomic, assign) int cacheTsNum;
@property (nonatomic, assign) int readBufferSize;
@property (nonatomic, assign) int receivedSize;
@property (nonatomic, strong) NSData* videoData;
@end

@implementation HLSProxyResponse {
@public
    NSData* _data;
    HLSDownloadToken* _downloadToken;
    dispatch_semaphore_t _semaphore;
    
}

//
// 返回ContentType:
//   m3u8 --> application/x-mpegURL
//   ts   --> video/MP2T
// 暂不考虑其他的格式的文件
//
+ (NSString *)getContentType:(NSString *)target {
    NSURL* url = [NSURL URLWithString:target];
    // 凡是以.ts结尾的都是ts文件，其他的为m3u8
    if ([url.pathExtension isEqualToString:@".ts"]) {
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
        self.downloadFinished = NO;
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
    if (NO) { // _data.length > 0) {
        self.contentLength = _data.length;
#if defined(DEBUG) || defined(NI_DEBUG)
        // 可以用于设置断点，进行Debug
        if ([self.targetUrl hasSuffix:@".m3u8"]) {
            NSString* str = [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding];
            str = nil;
        }
#endif
    } else {
        _data = nil;
        _readBufferSize = 0;
        _semaphore = dispatch_semaphore_create(0);

        // 准备开始下载数据
        @weakify(self)
        NSURL* url = [NSURL URLWithString:_targetUrl];
        _downloadToken = [[HLSDownloader sharedDownloader] downloadWithURL:url
                                                                   options:HLSDownloaderHighPriority
                                                                  progress:^(NSData* videoData,NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
                                                                      
                                                                      NIDPRINT(@"Download progress: %d", (int)receivedSize);
                                                                      
                                                                      @strongify(self)
                                                                      // m3u8文件需要等待，最终一口气传递过去
                                                                      // ts文件需要按照stream格式传递过去
                                                                      if ([self.targetUrl hasSuffix:@".ts"]) {
                                                                          self.videoData = videoData;
                                                                          self.receivedSize = (int)receivedSize;
                                                                          dispatch_semaphore_signal(self->_semaphore);
                                                                      }
                                                                  }
                                                                 completed:^(NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
                                                                     @strongify(self)
                                                                     if (self) {
                                                                         NIDPRINT(@"Download finished, Error: %@", error);
                                                                         // 如果有数据，且没有下载错误， 则进一步后处理数据和保存到Cache中
                                                                         if (data.length > 0 && error == nil) {
                                                                             
                                                                             // 非 .ts 文件，就是m3u8
                                                                             if (![self.targetUrl hasSuffix:@".ts"]) {
                                                                                 data = [self processM3U8:data baseUrl:url maxProxyLine:self.cacheTsNum];

#if defined(DEBUG) || defined(NI_DEBUG)
                                                                                 // 用于debug断点
                                                                                 NSString* dataStr = [[NSString alloc] initWithData:data
                                                                                                                           encoding:NSUTF8StringEncoding];
                                                                                 dataStr = nil;
#endif
                                                                             }

                                                                             
                                                                             [[HSLVideoCache sharedHlsCache] storeVideoData: data forKey:self.cacheKey completion:nil];
                                                                         }
                                                                         
                                                                         self.videoData = data;
                                                                         self.receivedSize = (int)data.length;
                                                                         self.downloadFinished = YES;

                                                                         dispatch_semaphore_signal(self->_semaphore);
                                                                     }
                                                                 }];
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

//
// 一定要读取到数据，可以等待，但是不能返回长度为0的数据；否则就表示结束了
//
- (void)asyncReadDataWithCompletion:(GCDWebServerBodyReaderCompletionBlock)completionBlockInner {
    
    NIDASSERT(_data.length == 0);
    
    if (_done) {
        NIDPRINT(@"Download Finished for %@", self.targetUrl);
        completionBlockInner([NSData data], nil);
        return;
    }
    
    
    // 不断等待，直到有足够的数据
    while (self.readBufferSize >= self.receivedSize && !self.downloadFinished) {
        dispatch_semaphore_wait(_semaphore, 100 * NSEC_PER_MSEC);
    }
    NIDPRINT(@"New Data to process or finished");
    int videoLength = self.receivedSize;
    int start = self.readBufferSize;
    self.readBufferSize = videoLength;
    
    if (self.downloadFinished) {
        _done = YES;
    }
    completionBlockInner([self.videoData subdataWithRange:NSMakeRange(start, videoLength - start)], nil);

    


    
    
   
    
//    NSURL* url = [NSURL URLWithString:_targetUrl];
//    
//    
//    // 这个地方比较关键
//    
//        NIDPRINT(@"Cache Miss, Get by URL: %@", url);
//        
//        // TODO: 优化
//
//        // 缓存数据
//        if (data.length > 0) {
//            [[HSLVideoCache sharedHlsCache] storeVideoData: data forKey:self.cacheKey completion:nil];
//        }
//    
//    // 数据处理完毕

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

