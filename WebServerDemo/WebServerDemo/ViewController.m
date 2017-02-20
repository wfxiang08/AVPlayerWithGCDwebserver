//
//  ViewController.m
//  WebServerDemo
//
//  Created by 广州加减信息技术有限公司 on 16/1/28.
//  Copyright © 2016年 奉强. All rights reserved.
//

#import "ViewController.h"
#import "HLSProxyServer.h"
#import <AVFoundation/AVFoundation.h>
#import "NIDebuggingTools.h"
#import "NSString+NSString_URLEndecode.h"



@implementation ViewController {
    AVPlayer *_player;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 确保被初始化
    [HLSProxyServer shareInstance];
    
}


- (void) playVideo {
     NSString *realUrlStr = @"http://192.168.20.167:8000/02/hls-low/playlist.m3u8";
//    NSString *realUrlStr = @"https://d2odow79s717pv.cloudfront.net/production/transcoding/recordings/6485234595397632/hlsmaster.m3u8";
    
    
    
    NSString *urlStr = [[HLSProxyServer shareInstance] getLocalURL:realUrlStr withHost:YES];
    
    NIDPRINT(@"PlayURL: %@", urlStr);
    
    NSURL *url = [NSURL URLWithString:urlStr];
    AVURLAsset *asset = [AVURLAsset assetWithURL:url];
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
    
    
    
    if (_player == nil) {
        _player = [AVPlayer playerWithPlayerItem:item];
        
        AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:_player];
        
        layer.frame = self.view.frame;
        
        [self.view.layer addSublayer:layer];
    } else {
        [_player pause];
        [_player replaceCurrentItemWithPlayerItem: item];
    }
    
    // 重新开始播放
    [_player play];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {

    [self playVideo];
 
    
}

- (void)stopWebServer {
    
    [[HLSProxyServer shareInstance] stopWebSever];
}

@end

