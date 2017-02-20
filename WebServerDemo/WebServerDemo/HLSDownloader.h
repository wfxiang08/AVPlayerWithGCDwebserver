/*
 * This file is part of the HLS package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>


typedef NS_OPTIONS(NSUInteger, HLSDownloaderOptions) {
    HLSDownloaderLowPriority = 1 << 0,
    HLSDownloaderProgressiveDownload = 1 << 1,

    /**
     * By default, request prevent the use of NSURLCache. With this flag, NSURLCache
     * is used with default policies.
     */
    HLSDownloaderUseNSURLCache = 1 << 2,

    /**
     * Call completion block with nil image/imageData if the image was read from NSURLCache
     * (to be combined with `HLSDownloaderUseNSURLCache`).
     */

    HLSDownloaderIgnoreCachedResponse = 1 << 3,
    /**
     * In iOS 4+, continue the download of the image if the app goes to background. This is achieved by asking the system for
     * extra time in background to let the request finish. If the background task expires the operation will be cancelled.
     */

    HLSDownloaderContinueInBackground = 1 << 4,

    /**
     * Handles cookies stored in NSHTTPCookieStore by setting 
     * NSMutableURLRequest.HTTPShouldHandleCookies = YES;
     */
    HLSDownloaderHandleCookies = 1 << 5,

    /**
     * Enable to allow untrusted SSL certificates.
     * Useful for testing purposes. Use with caution in production.
     */
    HLSDownloaderAllowInvalidSSLCertificates = 1 << 6,

    /**
     * Put the image in the high priority queue.
     */
    HLSDownloaderHighPriority = 1 << 7,
    
    /**
     * Scale down the image
     */
    HLSDownloaderScaleDownLargeImages = 1 << 8,
};

typedef NS_ENUM(NSInteger, HLSDownloaderExecutionOrder) {
    /**
     * Default value. All download operations will execute in queue style (first-in-first-out).
     */
    HLSDownloaderFIFOExecutionOrder,

    /**
     * All download operations will execute in stack style (last-in-first-out).
     */
    HLSDownloaderLIFOExecutionOrder
};

extern NSString * _Nonnull const HLSDownloadStartNotification;
extern NSString * _Nonnull const HLSDownloadStopNotification;

typedef void(^HLSDownloaderProgressBlock)(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL);

// 数据， 出错，是否结束
typedef void(^HLSDownloaderCompletedBlock)(NSData * _Nullable data, NSError * _Nullable error, BOOL finished);

typedef NSDictionary<NSString *, NSString *> SDHTTPHeadersDictionary;
typedef NSMutableDictionary<NSString *, NSString *> SDHTTPHeadersMutableDictionary;

typedef SDHTTPHeadersDictionary * _Nullable (^HLSDownloaderHeadersFilterBlock)(NSURL * _Nullable url, SDHTTPHeadersDictionary * _Nullable headers);


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// A token associated with each download. Can be used to cancel a download
@interface HLSDownloadToken : NSObject

@property (nonatomic, strong, nullable) NSURL *url;
@property (nonatomic, strong, nullable) id downloadOperationCancelToken;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 异步下载HLS相关的文件
@interface HLSDownloader : NSObject

// 最大的并发下载
// 根据网速估计动态调整？ 参考 ExoPlayer的算法来估计
@property (assign, nonatomic) NSInteger maxConcurrentDownloads;

// Shows the current amount of downloads that still need to be downloaded
@property (readonly, nonatomic) NSUInteger currentDownloadCount;


// 下载超时
@property (assign, nonatomic) NSTimeInterval downloadTimeout;


/**
 * Changes download operations execution order. Default value is `HLSDownloaderFIFOExecutionOrder`.
 */
@property (assign, nonatomic) HLSDownloaderExecutionOrder executionOrder;

// 单例
+ (nonnull instancetype)sharedDownloader;

/**
 *  Set the default URL credential to be set for request operations.
 */
@property (strong, nonatomic, nullable) NSURLCredential *urlCredential;


/**
 * Set filter to pick headers for downloading image HTTP request.
 *
 * This block will be invoked for each downloading image request, returned
 * NSDictionary will be used as headers in corresponding HTTP request.
 */
@property (nonatomic, copy, nullable) HLSDownloaderHeadersFilterBlock headersFilter;

/**
 * Creates an instance of a downloader with specified session configuration.
 * *Note*: `timeoutIntervalForRequest` is going to be overwritten.
 * @return new instance of downloader class
 */
- (nonnull instancetype)initWithSessionConfiguration:(nullable NSURLSessionConfiguration *)sessionConfiguration NS_DESIGNATED_INITIALIZER;

/**
 * Set a value for a HTTP header to be appended to each download HTTP request.
 *
 * @param value The value for the header field. Use `nil` value to remove the header.
 * @param field The name of the header field to set.
 */
- (void)setValue:(nullable NSString *)value forHTTPHeaderField:(nullable NSString *)field;

/**
 * Returns the value of the specified HTTP header field.
 *
 * @return The value associated with the header field field, or `nil` if there is no corresponding header field.
 */
- (nullable NSString *)valueForHTTPHeaderField:(nullable NSString *)field;


/**
 * Creates a HLSDownloader async downloader instance with a given URL
 *
 * The delegate will be informed when the image is finish downloaded or an error has happen.
 *
 * @see HLSDownloaderDelegate
 *
 * @param url            The URL to the image to download
 * @param options        The options to be used for this download
 * @param progressBlock  A block called repeatedly while the image is downloading
 *                       @note the progress block is executed on a background queue
 * @param completedBlock A block called once the download is completed.
 *                       If the download succeeded, the image parameter is set, in case of error,
 *                       error parameter is set with the error. The last parameter is always YES
 *                       if HLSDownloaderProgressiveDownload isn't use. With the
 *                       HLSDownloaderProgressiveDownload option, this block is called
 *                       repeatedly with the partial image object and the finished argument set to NO
 *                       before to be called a last time with the full image and finished argument
 *                       set to YES. In case of error, the finished argument is always YES.
 *
 * @return A token (HLSDownloadToken) that can be passed to -cancel: to cancel this operation
 */
// 如何下载给定的url
- (nullable HLSDownloadToken *)downloadWithURL:(nullable NSURL *)url
                                       options:(HLSDownloaderOptions)options
                                      progress:(nullable HLSDownloaderProgressBlock)progressBlock
                                     completed:(nullable HLSDownloaderCompletedBlock)completedBlock;


// 取消下载: Cancels a download that was previously queued using -downloadWithURL:options:progress:completed:
- (void)cancel:(nullable HLSDownloadToken *)token;

// 暂停
- (void)setSuspended:(BOOL)suspended;

// 取消所有的下载
- (void)cancelAllDownloads;

@end
