//
//  HLSProxyResponse.h
//
//  Created by Fei Wang on 2017/2/19.
//

#import <Foundation/Foundation.h>
#import "GCDWebServerResponse.h"
#import "CacheKeyFilter.h"

@interface HLSProxyResponse : GCDWebServerResponse

@property (nonatomic, copy) HLSCacheKeyFilterBlock keyFilter;

// tsNum 每个video缓存的ts的个数，如果为-1, 则表示全部缓存；至少 > 3
- (instancetype)initWithTargetUrl:(NSString*)targetUrl
                       cacheTsNum:(int)tsNum;

//
// 返回ContentType:
//   m3u8 --> application/x-mpegURL
//   ts   --> video/MP2T
// 暂不考虑其他的格式的文件
//
+ (NSString *)getContentType:(NSString *)target;
@end
