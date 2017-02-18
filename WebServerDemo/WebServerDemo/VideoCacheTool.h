//
//  VideoCacheTool.h
//  WebServerDemo
//
//  Created by 广州加减信息技术有限公司 on 16/2/18.
//  Copyright © 2016年 奉强. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VideoCacheTool : NSObject

@property (nonatomic, strong) NSString *localHttpHost;


- (NSString *)getLocalURL:(NSString *)realUrlString;

- (void)stopWebSever;

@end
