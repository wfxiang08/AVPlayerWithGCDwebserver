//
//  ViewController.m
//  WebServerDemo
//
//  Created by 广州加减信息技术有限公司 on 16/1/28.
//  Copyright © 2016年 奉强. All rights reserved.
//

#import "ViewController.h"
#import "VideoCacheTool.h"
#import <AVFoundation/AVFoundation.h>
#import "NIDebuggingTools.h"
#import "NSString+NSString_URLEndecode.h"


@interface ViewController ()

@property (nonatomic, strong) VideoCacheTool *videoCacheTool;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 初始化WebServer
    self.videoCacheTool = [[VideoCacheTool alloc] init];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {

    NSString *realUrlStr = @"http://192.168.31.187:8000/01/hls-low/playlist.m3u8";
    
    
    NSString *urlStr = [self.videoCacheTool getLocalURL:realUrlStr];
    
    NIDPRINT(@"PlayURL: %@", urlStr);

    NSURL *url = [NSURL URLWithString:urlStr];
    
    AVURLAsset *asset = [AVURLAsset assetWithURL:url];
    
    
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];


    
    AVPlayer *player = [AVPlayer playerWithPlayerItem:item];
    
    AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:player];
    
    layer.frame = self.view.frame;
    
    [self.view.layer addSublayer:layer];
    
    [player play];
    
}

- (void)stopWebServer {
    [self.videoCacheTool stopWebSever];
    self.videoCacheTool = nil;
}

@end

