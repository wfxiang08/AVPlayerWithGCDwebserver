/*
 * This file is part of the HLS package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "HLSDownloader.h"

extern NSString * _Nonnull const HLSDownloadStartNotification;
extern NSString * _Nonnull const HLSDownloadStopNotification;

extern NSString * _Nonnull const HLSDownloadReceiveResponseNotification;
extern NSString * _Nonnull const HLSDownloadFinishNotification;



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@interface HLSDownloaderOperation : NSOperation <NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

// The request used by the operation's task.
@property (strong, nonatomic, readonly, nullable) NSURLRequest *request;

/**
 * The operation's task
 */
@property (strong, nonatomic, readonly, nullable) NSURLSessionTask *dataTask;


/**
 * The credential used for authentication challenges in `-connection:didReceiveAuthenticationChallenge:`.
 *
 * This will be overridden by any shared credentials that exist for the username or password of the request URL, if present.
 */
@property (nonatomic, strong, nullable) NSURLCredential *credential;

/**
 * The HLSDownloaderOptions for the receiver.
 */
@property (assign, nonatomic, readonly) HLSDownloaderOptions options;

/**
 * The expected size of data.
 */
@property (assign, nonatomic) NSInteger expectedSize;

/**
 * The response returned by the operation's connection.
 */
@property (strong, nonatomic, nullable) NSURLResponse *response;

/**
 *  Initializes a `HLSDownloaderOperation` object
 *
 *  @see HLSDownloaderOperation
 *
 *  @param request        the URL request
 *  @param session        the URL session in which this operation will run
 *  @param options        downloader options
 *
 *  @return the initialized instance
 */
- (nonnull instancetype)initWithRequest:(nullable NSURLRequest *)request
                              inSession:(nullable NSURLSession *)session
                                options:(HLSDownloaderOptions)options NS_DESIGNATED_INITIALIZER;

/**
 *  Adds handlers for progress and completion. Returns a tokent that can be passed to -cancel: to cancel this set of
 *  callbacks.
 *
 *  @param progressBlock  the block executed when a new chunk of data arrives.
 *                        @note the progress block is executed on a background queue
 *  @param completedBlock the block executed when the download is done.
 *                        @note the completed block is executed on the main queue for success. If errors are found, there is a chance the block will be executed on a background queue
 *
 *  @return the token to use to cancel this set of handlers
 */
- (nullable id)addHandlersForProgress:(nullable HLSDownloaderProgressBlock)progressBlock
                            completed:(nullable HLSDownloaderCompletedBlock)completedBlock;

// 取消token对应的Operation, 返回整个Operation是否都取消了
- (BOOL)cancel:(nullable id)token;

@end
