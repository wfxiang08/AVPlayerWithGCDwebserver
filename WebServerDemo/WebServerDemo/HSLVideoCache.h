#import <Foundation/Foundation.h>

typedef void(^SDCacheQueryCompletedBlock)(NSData * _Nullable data);

typedef void(^SDWebImageCheckCacheCompletionBlock)(BOOL isInCache);

typedef void(^SDWebImageCalculateSizeBlock)(NSUInteger fileCount, NSUInteger totalSize);

typedef void(^HLSNoParamsBlock)();



@interface HSLVideoCache : NSObject

@property (nonatomic, assign) int maxCacheAge; // 单位: 秒，默认是: 3600 * 24 * 7 默认保存7天
@property (nonatomic, assign) int maxCacheSize; // 最多缓存文件: 5 * 100 --> 200M


// 异步地将Video保存到磁盘上
- (void)storeVideoData:(nullable NSData *)videoData
                forKey:(nullable NSString *)key
            completion:(nullable HLSNoParamsBlock)completionBlock;

//
// 将Video缓存到Disk上
//
- (void)storeVideoData:(nullable NSData *)videoData forKey:(nullable NSString *)key;


+ (nonnull instancetype)sharedHlsCache;
/**
 * Init a new cache store with a specific namespace and directory
 *
 * @param ns        The namespace to use for this cache store
 * @param directory Directory to cache disk images in
 */
- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                       diskCacheDirectory:(nonnull NSString *)directory NS_DESIGNATED_INITIALIZER;

- (nullable NSString *)makeDiskCachePath:(nonnull NSString*)fullNamespace;


// 异步检查是否存在指定的Key
- (void)videoExistsWithKey:(nullable NSString *)key
                completion:(nullable SDWebImageCheckCacheCompletionBlock)completionBlock;
- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSString *)key
                                               done:(nullable SDCacheQueryCompletedBlock)doneBlock;
//
// 返回给定key在本地的Cache
//
- (nullable NSData *)videoForKey:(nullable NSString *)key;


// 删除所有的Cache文件
- (void)deleteOldFiles;
//
// 删除所有的Cache文件
//
- (void)clearDiskOnCompletion:(nullable HLSNoParamsBlock)completion;

// 缓存统计相关的数据
- (NSUInteger)getSize;
- (NSUInteger)getDiskCount;
- (void)calculateSizeWithCompletionBlock:(nullable SDWebImageCalculateSizeBlock)completionBlock;
@end
