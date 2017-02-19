//
//  CacheKeyFilter.h
//
//  Created by Fei Wang on 2017/2/19.
//

#import <Foundation/Foundation.h>

// 给定一个URL，如何根据业务需求获取一个本地的HashKey

typedef NSString * _Nullable (^HLSCacheKeyFilterBlock)(NSURL * _Nullable url);

#ifdef __cplusplus
extern "C" {
#endif
    
FOUNDATION_EXPORT NSString * _Nullable SMDefaultCacheKeyFilter(NSURL * _Nullable url);
#ifdef __cplusplus
}
#endif

