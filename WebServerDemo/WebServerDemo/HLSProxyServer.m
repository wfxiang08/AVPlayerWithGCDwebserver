
#import "HLSProxyServer.h"
#import "HLSProxyResponse.h"

#import "GCDWebServer.h"
#import "GCDWebServerPrivate.h"

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
// 返回ContentType:
//   m3u8 --> application/x-mpegURL
//   ts   --> video/MP2T
// 暂不考虑其他的格式的文件
//
+ (NSString *)getContentType:(NSString *)target {
    
    if ([target rangeOfString:@".ts"].length > 0) {
        return @"video/MP2T";
    } else {
        return @"application/x-mpegURL";
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
        @weakify(self)
        [self.webServer addDefaultHandlerForMethod:@"GET"
                                      requestClass:[GCDWebServerRequest class]
                                 asyncProcessBlock:^(GCDWebServerRequest *request, GCDWebServerCompletionBlock completionBlock) {
                                     // 当前的handler该如何处理呢?
                                     // 迅速处理的request, 得到一个Response, 并且回调: completionBlock
                                     //                         Response本身不需要数据全部下载完毕，在completionBlock中会边读取，一边等待
                                     @strongify(self)
                                     [self hlsRequestHandler:request callback:completionBlock];
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



- (void) hlsRequestHandler:(GCDWebServerRequest *)request
                  callback:(GCDWebServerCompletionBlock) completionBlock {

    // 请求的段名
    NSString* target = [request.path substringFromIndex:[@"/video/" length]];
    
    
    NIDPRINT(@"RequestPath: %@", request.path);
    NIDPRINT(@"Target: %@", target);
    
    
    // 判断是否已经开始缓存了
    NSString* videoURL = [[self class] getVideoPath: target];
    NSString* contentType = [[self class] getContentType:target];
    NSString* fileName = target.lastPathComponent;
    
    NIDPRINT(@"VideoUrl: %@, ContentType: %@, fileName: %@", videoURL, contentType, fileName);
    
    
    HLSProxyResponse* response = [[HLSProxyResponse alloc] initHLSResponseWithContentType:contentType
                                                                                targetUrl:target
                                                                               cacheTsNum:3];
    
    // 这个应该算是立马返回了
    completionBlock(response);
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
