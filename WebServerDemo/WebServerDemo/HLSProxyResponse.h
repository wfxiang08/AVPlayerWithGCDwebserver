//
//  HLSProxyResponse.h
//
//  Created by Fei Wang on 2017/2/19.
//

#import <Foundation/Foundation.h>
#import "GCDWebServerResponse.h"

@interface HLSProxyResponse : GCDWebServerResponse

// tsNum 每个video缓存的ts的个数，如果为-1, 则表示全部缓存；至少 > 3
- (instancetype)initHLSResponseWithContentType:(NSString*)contentType
                                     targetUrl:(NSString*)targetUrl
                                    cacheTsNum:(int)tsNum;
@end
