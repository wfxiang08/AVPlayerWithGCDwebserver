#import <Foundation/Foundation.h>

@class GCDWebServer;
//
// 本地的 hls/m3u8代理服务器；不处理mp4和m4a等文件
//
@interface HLSProxyServer : NSObject

@property (nonatomic, readonly) NSString*_Nonnull localHttpHost;
@property (nonatomic, strong) GCDWebServer *webServer;

//
// 获取
//
+ (NSString*_Nonnull) getVideoPath:(NSString*_Nonnull)m3u8FileUrl;

//
// 获取 m3u8 文件，或 ts文件的ContentType
//
+ (NSString *_Nonnull)getContentType:(NSString *_Nonnull)target;

//
// 获取HLSProxyServer单例
//
+ (nonnull instancetype)shareInstance;


- (NSString*_Nonnull)getLocalURL:(NSString *_Nonnull)targetUrl;
- (void)stopWebSever;

@end
