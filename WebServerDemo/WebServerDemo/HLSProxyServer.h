#import <Foundation/Foundation.h>

//
// 本地的 hls/m3u8代理服务器；不处理mp4和m4a等文件
//
@interface HLSProxyServer : NSObject

@property (nonatomic, readonly) NSString *localHttpHost;

//
// 获取
//
+ (NSString*) getVideoPath:(NSString*)m3u8FileUrl;

//
// 获取 m3u8 文件，或 ts文件的ContentType
//
+ (NSString *)getContentType:(NSString *)target;

//
// 获取HLSProxyServer单例
//
+ (nonnull instancetype)shareInstance;


- (NSString *)getLocalURL:(NSString *)targetUrl;
- (void)stopWebSever;

@end
