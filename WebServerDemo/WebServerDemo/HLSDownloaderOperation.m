/*
 * This file is part of the HLS package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "HLSDownloaderOperation.h"

#import "NIDebuggingTools.h"

NSString *const HLSDownloadStartNotification = @"HLSDownloadStartNotification";
NSString *const HLSDownloadStopNotification = @"HLSDownloadStopNotification";

NSString *const HLSDownloadReceiveResponseNotification = @"HLSDownloadReceiveResponseNotification";

NSString *const HLSDownloadFinishNotification = @"HLSDownloadFinishNotification";

static NSString *const kProgressCallbackKey = @"progress";
static NSString *const kCompletedCallbackKey = @"completed";
static NSString *const HLSErrorDomain = @"HLSErrorDomain";

typedef NSMutableDictionary<NSString *, id> HLSCallbacksDictionary;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@interface HLSDownloaderOperation ()

@property (strong, nonatomic, nonnull) NSMutableArray<HLSCallbacksDictionary *> *callbackBlocks;

@property (assign, nonatomic, getter = isExecuting) BOOL executing;
@property (assign, nonatomic, getter = isFinished) BOOL finished;
@property (strong, nonatomic, nullable) NSMutableData *videoData;

// This is weak because it is injected by whoever manages this session. If this gets nil-ed out, we won't be able to run
// the task associated with this operation
@property (weak, nonatomic, nullable) NSURLSession *unownedSession;
// This is set if we're using not using an injected NSURLSession. We're responsible of invalidating this one
@property (strong, nonatomic, nullable) NSURLSession *ownedSession;

@property (strong, nonatomic, readwrite, nullable) NSURLSessionTask *dataTask;

@property (strong, nonatomic, nullable) dispatch_queue_t barrierQueue;


@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation HLSDownloaderOperation {
    
    BOOL responseFromCached;
}

@synthesize executing = _executing;
@synthesize finished = _finished;

- (nonnull instancetype)init {
    return [self initWithRequest:nil inSession:nil options:0];
}

// 初始化: HLSDownloaderOperation
- (nonnull instancetype)initWithRequest:(nullable NSURLRequest *)request
                              inSession:(nullable NSURLSession *)session
                                options:(HLSDownloaderOptions)options {
    if ((self = [super init])) {
        _request = [request copy];
        _options = options;
        _callbackBlocks = [NSMutableArray new];
        _executing = NO;
        _finished = NO;
        _expectedSize = 0;
        _unownedSession = session;
        
        // Initially wrong until `- URLSession:dataTask:willCacheResponse:completionHandler: is called or not called
        responseFromCached = YES;
        _barrierQueue = dispatch_queue_create("com.starmaker.HLSDownloaderOperationBarrierQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)dealloc {
    _barrierQueue = nil;
}

// 添加下载的回调: 进度/成功
- (nullable id)addHandlersForProgress:(nullable HLSDownloaderProgressBlock)progressBlock
                            completed:(nullable HLSDownloaderCompletedBlock)completedBlock {
    
    HLSCallbacksDictionary *callbacks = [NSMutableDictionary new];
    if (progressBlock) {
        callbacks[kProgressCallbackKey] = [progressBlock copy];
    }
    if (completedBlock) {
        callbacks[kCompletedCallbackKey] = [completedBlock copy];
    }
    
    // 通过: barrierQueue 来保护关键资源
    dispatch_barrier_async(self.barrierQueue, ^{
        [self.callbackBlocks addObject:callbacks];
    });
    return callbacks;
}

- (nullable NSArray<id> *)callbacksForKey:(NSString *)key {
    __block NSMutableArray<id> *callbacks = nil;
    
    dispatch_sync(self.barrierQueue, ^{
        // valueForKey的意义
        callbacks = [[self.callbackBlocks valueForKey:key] mutableCopy];
        // 删除[NSNull null], 不是所有的: kProgressCallbackKey 或者 kCompletedCallbackKey 都存在对应的信息
        [callbacks removeObjectIdenticalTo:[NSNull null]];
    });

    return [callbacks copy];
}

- (BOOL)cancel:(nullable id)token {
    
    __block BOOL shouldCancel = NO;
    dispatch_barrier_sync(self.barrierQueue, ^{
        
        // 删除某个Token
        [self.callbackBlocks removeObjectIdenticalTo:token];
        
        if (self.callbackBlocks.count == 0) {
            shouldCancel = YES;
        }
    });
    
    // 如果一个operation没有了引用，可以考虑取消
    if (shouldCancel) {
        [self cancel];
    }
    return shouldCancel;
}

- (void)start {
    @synchronized (self) {
        if (self.isCancelled) {
            self.finished = YES;
            [self reset];
            return;
        }


        if ([self shouldContinueWhenAppEntersBackground]) {
            
            UIApplication * app = [UIApplication sharedApplication];
            // 创建一个backgroundTask, 如果进入后台还继续下载
            @weakify(self)
            self.backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
                @strongify(self)
                if (self) {
                    [self cancel];

                    [app endBackgroundTask:self.backgroundTaskId];
                    self.backgroundTaskId = UIBackgroundTaskInvalid;
                }
            }];
        }

        // 启动时需要有一个Session, 一般情况下都会有，大家共享网络下载的链接
        NSURLSession *session = self.unownedSession;
        
        // 暂不考虑
        if (!self.unownedSession) {
            NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
            sessionConfig.timeoutIntervalForRequest = 15;
            
            /**
             *  Create the session for this task
             *  We send nil as delegate queue so that the session creates a serial operation queue for performing all delegate
             *  method calls and completion handler calls.
             */
            self.ownedSession = [NSURLSession sessionWithConfiguration:sessionConfig
                                                              delegate:self
                                                         delegateQueue:nil];
            session = self.ownedSession;
        }
        
        self.dataTask = [session dataTaskWithRequest:self.request];
        self.executing = YES;
    }
    
    [self.dataTask resume];

    if (self.dataTask) {
        for (HLSDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
            progressBlock(self.videoData, 0, NSURLResponseUnknownLength, self.request.URL);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:HLSDownloadStartNotification object:self];
        });
    } else {
        [self callCompletionBlocksWithError:[NSError errorWithDomain:NSURLErrorDomain
                                                                code:0
                                                            userInfo:@{NSLocalizedDescriptionKey : @"Connection can't be initialized"}]];
    }


    if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
        UIApplication * app = [UIApplication sharedApplication];
        [app endBackgroundTask:self.backgroundTaskId];
        self.backgroundTaskId = UIBackgroundTaskInvalid;
    }

}

- (void)cancel {
    @synchronized (self) {
        [self cancelInternal];
    }
}

- (void)cancelInternal {
    if (self.isFinished) {
        return;
    } else {
        [super cancel];
    }

    if (self.dataTask) {
        [self.dataTask cancel];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:HLSDownloadStopNotification object:self];
        });

        // As we cancelled the connection, its callback won't be called and thus won't
        // maintain the isFinished and isExecuting flags.
        if (self.isExecuting) {
            self.executing = NO;
        }
        if (!self.isFinished){
            self.finished = YES;
        }
    }

    [self reset];
}

- (void)done {
    self.finished = YES;
    self.executing = NO;
    [self reset];
}

- (void)reset {
    dispatch_barrier_async(self.barrierQueue, ^{
        [self.callbackBlocks removeAllObjects];
    });
    self.dataTask = nil;
    self.videoData = nil;
    if (self.ownedSession) {
        [self.ownedSession invalidateAndCancel];
        self.ownedSession = nil;
    }
}

- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isConcurrent {
    return YES;
}

#pragma mark NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    
    //'304 Not Modified' is an exceptional one
    if (![response respondsToSelector:@selector(statusCode)]
            || (((NSHTTPURLResponse *)response).statusCode < 400 && ((NSHTTPURLResponse *)response).statusCode != 304)) {
        
        NSInteger expected = response.expectedContentLength > 0 ? (NSInteger)response.expectedContentLength : 0;
        self.expectedSize = expected;
        
        NIDPRINT(@"Receiving Data begins");
        self.videoData = [[NSMutableData alloc] initWithCapacity:expected];
        self.response = response;
        
        // 状态码异常， 直接报错
        for (HLSDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
            progressBlock(self.videoData, 0, expected, self.request.URL);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:HLSDownloadReceiveResponseNotification object:self];
        });
    } else {
        NSUInteger code = ((NSHTTPURLResponse *)response).statusCode;
        
        //This is the case when server returns '304 Not Modified'. It means that remote image is not changed.
        //In case of 304 we need just cancel the operation and return cached image from the cache.
        if (code == 304) {
            [self cancelInternal];
        } else {
            [self.dataTask cancel];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:HLSDownloadStopNotification object:self];
        });
        
        [self callCompletionBlocksWithError:[NSError errorWithDomain:NSURLErrorDomain
                                                                code:((NSHTTPURLResponse *)response).statusCode userInfo:nil]];

        [self done];
    }
    
    if (completionHandler) {
        completionHandler(NSURLSessionResponseAllow);
    }
}

//
// 在下载过程中能看到数据， 这个可以实时Feed给播放器
//
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    
    NIDASSERT(self.videoData);

    // 积攒数据
    // 依赖服务器端的假设: video的数据足够小，可以放在内存中
    [self.videoData appendData:data];

    for (HLSDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
        progressBlock(self.videoData, self.videoData.length, self.expectedSize, self.request.URL);
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler {

    responseFromCached = NO; // If this method is called, it means the response wasn't read from cache
    NSCachedURLResponse *cachedResponse = proposedResponse;

    // 是否可以缓存当前的Response, 主要看cachePolicy
    if (self.request.cachePolicy == NSURLRequestReloadIgnoringLocalCacheData) {
        cachedResponse = nil;
    }
    
    if (completionHandler) {
        completionHandler(cachedResponse);
    }
}

#pragma mark NSURLSessionTaskDelegate

- (void)    URLSession:(NSURLSession *)session
                  task:(NSURLSessionTask *)task
  didCompleteWithError:(NSError *)error {
    
    @synchronized(self) {
        self.dataTask = nil;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // 通知Task停止，完成
            [[NSNotificationCenter defaultCenter] postNotificationName:HLSDownloadStopNotification object:self];
            
            if (!error) {
                [[NSNotificationCenter defaultCenter] postNotificationName:HLSDownloadFinishNotification object:self];
            }
        });
    }
    
    if (error) {
        // 下载出错
        [self callCompletionBlocksWithError:error];
    
    } else {
        // 如果有completeCallback, 就通知
        if ([self callbacksForKey:kCompletedCallbackKey].count > 0) {
            /**
             *  See #1608 and #1623 - apparently, there is a race condition on `NSURLCache` that causes a crash
             *  Limited the calls to `cachedResponseForRequest:` only for cases where we should ignore the cached response
             *    and images for which responseFromCached is YES (only the ones that cannot be cached).
             *  Note: responseFromCached is set to NO inside `willCacheResponse:`. This method doesn't get called for large images or images behind authentication
             */
            if (self.options & HLSDownloaderIgnoreCachedResponse && responseFromCached
                    && [[NSURLCache sharedURLCache] cachedResponseForRequest:self.request]) {
                
                // hack
                [self callCompletionBlocksWithData:nil error:nil finished:YES];
            } else if (self.videoData) {
                // self.videoData
                // TODO:
                [self callCompletionBlocksWithData:self.videoData error:nil finished:YES];
            } else {
                // 没有数据
                [self callCompletionBlocksWithError:[NSError errorWithDomain:HLSErrorDomain
                                                                        code:0
                                                                    userInfo:@{NSLocalizedDescriptionKey : @"Video data is nil"}]];
            }
        }
    }
    [self done];
}

// 暂不考虑
- (void)    URLSession:(NSURLSession *)session
                  task:(NSURLSessionTask *)task
   didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
     completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition,
                                 NSURLCredential *credential))completionHandler {
    
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    __block NSURLCredential *credential = nil;
    
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        if (!(self.options & HLSDownloaderAllowInvalidSSLCertificates)) {
            disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        } else {
            credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            disposition = NSURLSessionAuthChallengeUseCredential;
        }
    } else {
        if (challenge.previousFailureCount == 0) {
            if (self.credential) {
                credential = self.credential;
                disposition = NSURLSessionAuthChallengeUseCredential;
            } else {
                disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
            }
        } else {
            disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        }
    }
    
    if (completionHandler) {
        completionHandler(disposition, credential);
    }
}

#pragma mark Helper methods

// 是否后台继续运行
- (BOOL)shouldContinueWhenAppEntersBackground {
    return self.options & HLSDownloaderContinueInBackground;
}

//
// 下载任务结束
//
- (void)callCompletionBlocksWithError:(nullable NSError *)error {
    [self callCompletionBlocksWithData:self.videoData
                                 error:error
                              finished:YES];
}

- (void)callCompletionBlocksWithData:(nullable NSData *)videoData
                               error:(nullable NSError *)error
                                finished:(BOOL)finished {
    
    NSArray<id> *completionBlocks = [self callbacksForKey:kCompletedCallbackKey];
    // 通知完成调用
    dispatch_main_async_safe(^{
        for (HLSDownloaderCompletedBlock completedBlock in completionBlocks) {
            completedBlock(videoData, error, finished);
        }
    });
}

@end
