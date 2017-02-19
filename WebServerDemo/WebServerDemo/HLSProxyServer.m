
#import "HLSProxyServer.h"
#import "HLSProxyResponse.h"

#import "GCDWebServer.h"
// #import "GCDWebServerPrivate.h"

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

// 视频的URL格式: http://localhost/video/?target=xxxxx
#define kVideoPath @"/video/"
#define kTarget @"target"

- (NSString *)getLocalURL:(NSString *)realUrlString withHost: (BOOL)withHost {
    if (withHost) {
        return [NSString stringWithFormat:@"%@video/?target=%@",
                        self.localHttpHost, [realUrlString URLEncode]];
    } else {
        return [NSString stringWithFormat:@"/video/?target=%@", [realUrlString URLEncode]];
    }
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
        
        [self.webServer addHandlerForMethod:@"GET"
                                       path:kVideoPath
                               requestClass:[GCDWebServerRequest class]
                          asyncProcessBlock:^(GCDWebServerRequest *request, GCDWebServerCompletionBlock completionBlock) {
                                 NSString* target = request.query[kTarget];
                                 HLSProxyResponse* response = [[HLSProxyResponse alloc] initWithTargetUrl:target
                                                                                               cacheTsNum:3];
                                 completionBlock(response);
                             }];
        
        
        // 绑定到localhost
        NSMutableDictionary* options = [NSMutableDictionary dictionary];
        [options setValue:@(YES) forKey:GCDWebServerOption_BindToLocalhost];
        BOOL started = [self.webServer startWithOptions:options error:nil];
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

- (void)stopWebSever {
    [self.webServer stop];
}

@end
