#import <Foundation/Foundation.h>




@class GCDWebServer;
//
// 本地的 hls/m3u8代理服务器；不处理mp4和m4a等文件
//
@interface HLSProxyServer : NSObject

@property (nonatomic, readonly) NSString*_Nonnull localHttpHost;
@property (nonatomic, strong) GCDWebServer *_Nonnull webServer;

//
// 获取
//
+ (NSString*_Nonnull) getVideoPath:(NSString*_Nonnull)m3u8FileUrl;

//
// 获取HLSProxyServer单例
//
+ (nonnull instancetype)shareInstance;


- (NSString *)getLocalURL:(NSString *)realUrlString withHost: (BOOL)withHost;

- (void)stopWebSever;

@end
