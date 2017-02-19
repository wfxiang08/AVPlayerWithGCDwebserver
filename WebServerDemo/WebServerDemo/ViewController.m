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


@interface ViewController ()<AVAssetDownloadDelegate>

@property (nonatomic, strong) VideoCacheTool *videoCacheTool;

@end

@implementation ViewController {
    NSURLSessionConfiguration* urlSessionConfiguration;
    AVAssetDownloadURLSession* avAssetDownloadSession;
    AVAssetDownloadTask* avAssetDownloadTask;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 初始化WebServer
     self.videoCacheTool = [[VideoCacheTool alloc] init];
    
    [self playVideo];
}



- (void)setupAssetDownloader {
    NSURL *assetURL = [NSURL URLWithString:@"http://192.168.31.187:8000/02/hls-low/playlist.m3u8"];
    AVURLAsset *hlsAsset = [AVURLAsset assetWithURL:assetURL];
    
    urlSessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"assetDowloadConfigIdentifier"];
    avAssetDownloadSession = [AVAssetDownloadURLSession sessionWithConfiguration:urlSessionConfiguration
                                                           assetDownloadDelegate:self
                                                                   delegateQueue:[NSOperationQueue mainQueue]];
    
    // Download movie
    avAssetDownloadTask = [avAssetDownloadSession assetDownloadTaskWithURLAsset:hlsAsset
                                                                     assetTitle:@"downloadedMedia"
                                                               assetArtworkData:nil options:nil];
    
    //@{AVAssetDownloadTaskMinimumRequiredMediaBitrateKey : @(300000)}
    
    
    [avAssetDownloadTask resume];
    
    AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithAsset:avAssetDownloadTask.URLAsset];
    AVPlayer *player = [[AVPlayer alloc ] initWithPlayerItem:playerItem];
    AVPlayerLayer *playerLayer = [[AVPlayerLayer alloc ] init];
    [playerLayer setPlayer:player];
    [playerLayer setFrame:self.view.frame];
    [self.view.layer addSublayer:playerLayer];
    [player play];
}

#pragma mark - AVAssetDownloadDelegate

- (void)URLSession:(NSURLSession *)session assetDownloadTask:(AVAssetDownloadTask *)assetDownloadTask
didResolveMediaSelection:(AVMediaSelection *)resolvedMediaSelection {
    NIDPRINTMETHODNAME();
}
- (void)URLSession:(NSURLSession *)session assetDownloadTask:(AVAssetDownloadTask *)assetDownloadTask
  didLoadTimeRange:(CMTimeRange)timeRange totalTimeRangesLoaded:(NSArray<NSValue *> *)loadedTimeRanges timeRangeExpectedToLoad:(CMTimeRange)timeRangeExpectedToLoad {
    NSInteger percent = 0;
    for (NSValue *value in loadedTimeRanges) {
        CMTimeRange timeRange = [value CMTimeRangeValue];
        percent += CMTimeGetSeconds(timeRange.duration) / CMTimeGetSeconds(timeRangeExpectedToLoad.duration);
    }
    percent *= 100;
    NSLog(@"Progress: %ld", (long)percent);
}

- (void)URLSession:(NSURLSession *)session assetDownloadTask:(AVAssetDownloadTask *)assetDownloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSString *localPath = location.relativePath;
    NSLog(@"localPath: %@", localPath);
    // TODO: Play downloaded file
    // IMPORTANT: Don't move this file to another location.
}
- (void) playVideo {
    NSString *realUrlStr = @"http://192.168.31.187:8000/02/hls-low/playlist.m3u8";
    
    
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

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {

    
 
    
}

- (void)stopWebServer {
    [self.videoCacheTool stopWebSever];
    self.videoCacheTool = nil;
}

@end

