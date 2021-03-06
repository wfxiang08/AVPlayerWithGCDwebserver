#import <Foundation/Foundation.h>

@class GCDWebServer;
//
// 本地的 hls/m3u8代理服务器；不处理mp4和m4a等文件
//
@interface HLSProxyServer : NSObject

@property (nonatomic, readonly) NSString*_Nonnull localHttpHost;
@property (nonatomic, strong) GCDWebServer *_Nonnull webServer;


//
// 获取HLSProxyServer单例
//
+ (nonnull instancetype)shareInstance;


- (NSString*_Nonnull)getLocalURL:(NSString*_Nonnull)realUrlString withHost: (BOOL)withHost;

- (void)stopWebSever;

@end
