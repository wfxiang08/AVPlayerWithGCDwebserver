
#import "HLSProxyServer.h"
#import "HLSProxyResponse.h"

#import "GCDWebServer.h"
#import "GCDWebServerPrivate.h"

// 缓存逻辑
#import "HSLVideoCache.h"

#import "VideoCacheManager.h"
#import "NIDebuggingTools.h"
#import "NSString+NSString_URLEndecode.h"



@interface HLSProxyServer ()
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation HLSProxyServer

+ (nonnull instancetype)shareInstance {
    static dispatch_once_t once;
    static HLSProxyServer* instance;
    dispatch_once(&once, ^{
        instance = [[HLSProxyServer alloc] init];
    });
    return instance;
}


//
// 初始化HLSProxyServer
//
- (instancetype)init {
    if (self = [super init]) {
        
        // 初始化本地web服务器
        self.webServer = [[GCDWebServer alloc] init];
        
        // 添加一个get响应
        // 如何代理请求呢?
        // 局限于：m3u8
        // 重点: 设置webServer的callback
        [self.webServer addDefaultHandlerForMethod:@"GET"
                                      requestClass:[GCDWebServerRequest class]
                                 asyncProcessBlock:^(GCDWebServerRequest *request, GCDWebServerCompletionBlock completionBlock) {
                                     // 当前的handler该如何处理呢?
                                     // 迅速处理的request, 得到一个Response, 并且回调: completionBlock
                                     //                         Response本身不需要数据全部下载完毕，在completionBlock中会边读取，一边等待
                                     // 请求的段名
                                     NSString* target = [request.path substringFromIndex:[@"/video/" length]];
                                     
                                     
                                     NIDPRINT(@"Target: %@", target);
                                     HLSProxyResponse* response = [[HLSProxyResponse alloc] initWithTargetUrl:target
                                                                                                   cacheTsNum:3];
                                     
                                     // 这个应该算是立马返回了
                                     completionBlock(response);
                                 }];
        
        
        BOOL started = [self.webServer start];
        if (!started) {
            NIDPRINT(@"WebServer Started Failed");
        }
        
        
        //设置服务器的本地url
        _localHttpHost = self.webServer.serverURL.relativeString;
    }
    return self;
}

- (void) dealloc {
    NIDPRINTMETHODNAME();
}


+ (NSString*) getVideoPath:(NSString*)m3u8FileUrl {

    NSRange range = [m3u8FileUrl rangeOfString:@"/" options:NSBackwardsSearch];
    NSString* result = [m3u8FileUrl substringToIndex: range.location];
    
    NIDPRINT(@"VideoPath: %@ <-- %@", result, m3u8FileUrl);
    return result;
}

- (NSString *)getLocalURL:(NSString *)realUrlString {
    
    NSString *urlStr = [NSString stringWithFormat:@"%@video/%@",
                        self.localHttpHost, [realUrlString URLEncode]];
    
    return urlStr;
}


- (void)stopWebSever {
    [self.webServer stop];
}

@end
