//
//  HLSProxyResponse.h
//
//  Created by Fei Wang on 2017/2/19.
//

#import <Foundation/Foundation.h>
#import "GCDWebServerResponse.h"

@interface HLSProxyResponse : GCDWebServerResponse

+ (instancetype)responseWithContentType:(NSString*)contentType
                              targetUrl:(NSString*)targetUrl;
@end
