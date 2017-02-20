/*
 * This file is part of the HLS package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "HLSDownloader.h"
#import "HLSDownloaderOperation.h"
#import "NIDebuggingTools.h"


@implementation HLSDownloadToken
@end


@interface HLSDownloader () <NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

@property (strong, nonatomic, nonnull) NSOperationQueue *downloadQueue;
@property (weak, nonatomic, nullable) NSOperation *lastAddedOperation;

@property (strong, nonatomic, nonnull) NSMutableDictionary<NSURL *, HLSDownloaderOperation *> *URLOperations;
@property (strong, nonatomic, nullable) SDHTTPHeadersMutableDictionary *HTTPHeaders;
// This queue is used to serialize the handling of the network responses of all the download operation in a single queue
@property (strong, nonatomic, nullable) dispatch_queue_t barrierQueue;

// The session in which data tasks will run
@property (strong, nonatomic) NSURLSession *session;

@end

@implementation HLSDownloader

+ (void)initialize {
    // Bind SDNetworkActivityIndicator if available (download it here: http://github.com/rs/SDNetworkActivityIndicator )
    // To use it, just add #import "SDNetworkActivityIndicator.h" in addition to the HLS import
    if (NSClassFromString(@"SDNetworkActivityIndicator")) {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id activityIndicator = [NSClassFromString(@"SDNetworkActivityIndicator")
                                performSelector:NSSelectorFromString(@"sharedActivityIndicator")];
#pragma clang diagnostic pop

        // Remove observer in case it was previously added.
        [[NSNotificationCenter defaultCenter] removeObserver:activityIndicator
                                                        name:HLSDownloadStartNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:activityIndicator
                                                        name:HLSDownloadStopNotification object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:activityIndicator
                                                 selector:NSSelectorFromString(@"startActivity")
                                                     name:HLSDownloadStartNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:activityIndicator
                                                 selector:NSSelectorFromString(@"stopActivity")
                                                     name:HLSDownloadStopNotification object:nil];
    }
}

+ (nonnull instancetype)sharedDownloader {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (nonnull instancetype)init {
    return [self initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
}

// 初始化
- (nonnull instancetype)initWithSessionConfiguration:(nullable NSURLSessionConfiguration *)sessionConfiguration {
    if ((self = [super init])) {

        _executionOrder = HLSDownloaderFIFOExecutionOrder;

        _downloadQueue = [NSOperationQueue new];
        _downloadQueue.maxConcurrentOperationCount = 6;
        _downloadQueue.name = @"com.startmaker.HLSDownloader";
        _URLOperations = [NSMutableDictionary new];

        _barrierQueue = dispatch_queue_create("com.startmaker.HLSDownloaderBarrierQueue", DISPATCH_QUEUE_CONCURRENT);
        _downloadTimeout = 15.0;

        sessionConfiguration.timeoutIntervalForRequest = _downloadTimeout;

        // Create the session for this task
        // We send nil as delegate queue so that the session creates a serial operation queue for performing all delegate
        // method calls and completion handler calls.
        self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration
                                                     delegate:self
                                                delegateQueue:nil];
    }
    return self;
}

// 取消Session中的所有的下载
- (void)dealloc {
    [self.session invalidateAndCancel];
    self.session = nil;

    [self.downloadQueue cancelAllOperations];
    _barrierQueue = nil;
}

- (void)setValue:(nullable NSString *)value forHTTPHeaderField:(nullable NSString *)field {
    if (value) {
        self.HTTPHeaders[field] = value;
    } else {
        [self.HTTPHeaders removeObjectForKey:field];
    }
}

- (nullable NSString *)valueForHTTPHeaderField:(nullable NSString *)field {
    return self.HTTPHeaders[field];
}

- (void)setMaxConcurrentDownloads:(NSInteger)maxConcurrentDownloads {
    // 如何控制最大的并发度
    _downloadQueue.maxConcurrentOperationCount = maxConcurrentDownloads;
}

- (NSUInteger)currentDownloadCount {
    return _downloadQueue.operationCount;
}

- (NSInteger)maxConcurrentDownloads {
    return _downloadQueue.maxConcurrentOperationCount;
}


//
// 如何下载给定的url
//
- (nullable HLSDownloadToken *)downloadWithURL:(nullable NSURL *)url
                                       options:(HLSDownloaderOptions)options
                                      progress:(nullable HLSDownloaderProgressBlock)progressBlock
                                     completed:(nullable HLSDownloaderCompletedBlock)completedBlock {
    
    @weakify(self)
    return [self addProgressCallback:progressBlock
                      completedBlock:completedBlock
                              forURL:url
                      createCallback:^HLSDownloaderOperation *{

        @strongify(self)
        NSTimeInterval timeoutInterval = self.downloadTimeout;
        if (timeoutInterval == 0.0) {
            timeoutInterval = 15.0;
        }

        NSURLRequestCachePolicy policy = (options & HLSDownloaderUseNSURLCache) ? NSURLRequestUseProtocolCachePolicy : NSURLRequestReloadIgnoringLocalCacheData;

        // In order to prevent from potential duplicate caching (NSURLCache + SDImageCache) we disable the cache for image requests if told otherwise
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url
                                                                    cachePolicy:policy
                                                                timeoutInterval:timeoutInterval];

        request.HTTPShouldHandleCookies = (options & HLSDownloaderHandleCookies);
        request.HTTPShouldUsePipelining = YES;

        if (self.headersFilter) {
            request.allHTTPHeaderFields = self.headersFilter(url, [self.HTTPHeaders copy]);
        } else {
            request.allHTTPHeaderFields = self.HTTPHeaders;
        }

        // 构建Operation: request --> operation
        HLSDownloaderOperation *operation = [[HLSDownloaderOperation alloc] initWithRequest:request
                                                                                  inSession:self.session
                                                                                    options:options];
        if (self.urlCredential) {
            operation.credential = self.urlCredential;
        }

        // 下载的优先级控制, 例如: 预加载可以低优先级来做
        if (options & HLSDownloaderHighPriority) {
            operation.queuePriority = NSOperationQueuePriorityHigh;
        } else if (options & HLSDownloaderLowPriority) {
            operation.queuePriority = NSOperationQueuePriorityLow;
        }

        // 开始执行:
        [self.downloadQueue addOperation:operation];

        // 执行顺序?
        if (self.executionOrder == HLSDownloaderLIFOExecutionOrder) {
            // Emulate LIFO execution order by systematically adding new operations as last operation's dependency
            [self.lastAddedOperation addDependency:operation];
            self.lastAddedOperation = operation;
        }

        return operation;
    }];
}

//
// 如何取消下载呢?
//
- (void)cancel:(nullable HLSDownloadToken *)token {
    dispatch_barrier_async(self.barrierQueue, ^{
        HLSDownloaderOperation *operation = self.URLOperations[token.url];
        
        BOOL canceled = [operation cancel:token.downloadOperationCancelToken];
        if (canceled) {
            [self.URLOperations removeObjectForKey:token.url];
        }
    });
}

- (nullable HLSDownloadToken *)addProgressCallback:(HLSDownloaderProgressBlock)progressBlock
                                    completedBlock:(HLSDownloaderCompletedBlock)completedBlock
                                            forURL:(nullable NSURL *)url
                                    createCallback:(HLSDownloaderOperation *(^)())createCallback {
    
    // 如果没有指定url, 则直接报错
    if (url == nil) {
        if (completedBlock != nil) {
            completedBlock(nil, nil, NO);
        }
        return nil;
    }

    __block HLSDownloadToken *token = nil;

    dispatch_barrier_sync(self.barrierQueue, ^{
        // 看是否已经开始下载了
        HLSDownloaderOperation *operation = self.URLOperations[url];
        
        if (!operation) {
            // 如何创建 Operation呢?
            operation = createCallback();
            self.URLOperations[url] = operation;


            __weak HLSDownloaderOperation *woperation = operation;
            operation.completionBlock = ^{
                HLSDownloaderOperation *soperation = woperation;
                if (!soperation) return;
                
                // 完成之后，从URLOperations中删除自己
                if (self.URLOperations[url] == soperation) {
                    [self.URLOperations removeObjectForKey:url];
                };
            };
        }
        
        // 同一个Operation, 就不再重复处理，一起添加 progressBlock/completeBlock
        id downloadOperationCancelToken = [operation addHandlersForProgress:progressBlock
                                                                  completed:completedBlock];

        // 创建一个新的: HSLDownloadToken, 核心是url以及token
        token = [HLSDownloadToken new];
        token.url = url;
        token.downloadOperationCancelToken = downloadOperationCancelToken;
    });

    return token;
}

- (void)setSuspended:(BOOL)suspended {
    self.downloadQueue.suspended = suspended;
}

- (void)cancelAllDownloads {
    [self.downloadQueue cancelAllOperations];
}

#pragma mark Helper methods

// 获取Task对应的Operation
- (HLSDownloaderOperation *)operationWithTask:(NSURLSessionTask *)task {
    HLSDownloaderOperation *returnOperation = nil;
    
    // 通过taskIdentifier 来识别Operation
    for (HLSDownloaderOperation *operation in self.downloadQueue.operations) {
        if (operation.dataTask.taskIdentifier == task.taskIdentifier) {
            returnOperation = operation;
            break;
        }
    }
    return returnOperation;
}

#pragma mark NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {

    // Identify the operation that runs this task and pass it the delegate method
    HLSDownloaderOperation *dataOperation = [self operationWithTask:dataTask];

    [dataOperation URLSession:session
                     dataTask:dataTask
           didReceiveResponse:response
            completionHandler:completionHandler];
}

//
// 又收到新的数据
//
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {

    HLSDownloaderOperation *dataOperation = [self operationWithTask:dataTask];

    [dataOperation URLSession:session
                     dataTask:dataTask
               didReceiveData:data];
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler {

    // Identify the operation that runs this task and pass it the delegate method
    HLSDownloaderOperation *dataOperation = [self operationWithTask:dataTask];

    [dataOperation URLSession:session
                     dataTask:dataTask
            willCacheResponse:proposedResponse
            completionHandler:completionHandler];
}

#pragma mark NSURLSessionTaskDelegate

- (void)    URLSession:(NSURLSession *)session
                  task:(NSURLSessionTask *)task
  didCompleteWithError:(NSError *)error {
    // 任务完成
    HLSDownloaderOperation *dataOperation = [self operationWithTask:task];

    [dataOperation URLSession:session task:task didCompleteWithError:error];
}

// 如何处理重定向呢?
- (void)        URLSession:(NSURLSession *)session
                      task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
                newRequest:(NSURLRequest *)request
         completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    
    completionHandler(request);
}


//
// 如果需要授权，该如何做?
//
- (void)    URLSession:(NSURLSession *)session
                  task:(NSURLSessionTask *)task
   didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
     completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {

    // Identify the operation that runs this task and pass it the delegate method
    HLSDownloaderOperation *dataOperation = [self operationWithTask:task];

    [dataOperation URLSession:session
                         task:task
          didReceiveChallenge:challenge
            completionHandler:completionHandler];
}

@end
