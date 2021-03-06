//
//  ViewController.m
//  Blog-Getting-Started-with-Vision-OC
//
//  Created by 张雄 on 2018/5/29.
//  Copyright © 2018年 张雄. All rights reserved.
//

#import "ViewController.h"
#import <Vision/Vision.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (weak, nonatomic) IBOutlet UIView *cameraView;
@property (weak, nonatomic) IBOutlet UIView *highlightView;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *cameraLayer;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) VNSequenceRequestHandler *visionSequenceHandle;
@property (nonatomic, strong) VNDetectedObjectObservation *lastObservation;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupUI];

    // 注册接收相机缓冲区
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [videoOutput setSampleBufferDelegate:self queue: dispatch_queue_create("MyQueue", NULL)];
    [self.captureSession addOutput:videoOutput];
    // 让 session 开始
    [self.captureSession startRunning];
    
}

- (void)setupUI {
    
    // 隐藏红色框视图
    self.highlightView.frame = CGRectZero;
    
    self.highlightView.layer.borderColor = [[UIColor redColor] CGColor];
    self.highlightView.layer.borderWidth = 4.0;
    self.highlightView.backgroundColor = [UIColor clearColor];
    
    
    // 让 camera 实时获取的视频出现在屏幕上
    [self.cameraView.layer addSublayer:self.cameraLayer];
    
}

- (void)viewDidLayoutSubviews {
    
    [super viewDidLayoutSubviews];
    
        // 让 layer 获得正确的大小
    self.cameraLayer.frame = self.cameraView.bounds;
    
    
}


#pragma mark - 重置追踪
- (IBAction)resetTrack:(UIBarButtonItem *)sender {
    
    self.lastObservation = nil;
    self.highlightView.frame = CGRectZero;
}


#pragma mark - 点击选框
- (IBAction)userTapped:(UITapGestureRecognizer *)sender {
    
    // 每次点击时需要重置一次追踪
    self.lastObservation = nil;
    self.highlightView.frame = CGRectZero;
    
    // 获取点击的中点
    self.highlightView.frame = CGRectMake(0, 0, 120, 120);
    self.highlightView.center = [sender locationInView:self.view];
    
    // 为 观察对象 转换矩阵
    CGRect originalRect = self.highlightView.frame;
    CGRect converteRect = [self.cameraLayer metadataOutputRectOfInterestForRect:originalRect];
    converteRect.origin.y = 1 - converteRect.origin.y;
    
    // 设置观察对象
    VNDetectedObjectObservation *newObservation = [VNDetectedObjectObservation observationWithBoundingBox:converteRect];
    self.lastObservation = newObservation;
    
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    // 确保像素转换区可以被转换
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // 确保持有一个 老观察对象 来满足一个进行请求的条件
    if (!self.lastObservation) {
        // 如果不存在直接返回
        return;
    }
    // 创建请求
    VNTrackObjectRequest *request = [[VNTrackObjectRequest alloc] initWithDetectedObjectObservation:self.lastObservation completionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        [self handleVisionRequestUpdate:request error:error];
    }];
    
//    VNTrackObjectRequest *request = [[VNTrackObjectRequest alloc] initWithDetectedObjectObservation:self.lastObservation completionHandler:nil];
    // 快速识别和精确识别
    // VNRequestTrackingLevelAccurate 精确的
    // VNRequestTrackingLevelFast 快速的
    request.trackingLevel = VNRequestTrackingLevelFast;
    
    // 执行请求
    NSError *error = nil;
    [self.visionSequenceHandle performRequests:@[request] onCVPixelBuffer:pixelBuffer error:&error];
    if (error) {
        NSLog(@"error: %@", error);
    }
    
}

//typedef void (^VNRequestCompletionHandler)(VNRequest *request, NSError * _Nullable error);
//

#pragma mark - 处理 Vision 请求管理更新
- (void)handleVisionRequestUpdate:(VNRequest *)request error:(NSError *)error {
    
    // 主队列里面 进行非原子性非线程安全属性
    dispatch_async(dispatch_get_main_queue(), ^{
        // 类型不正确就直接返回
        if (![request.results.firstObject isKindOfClass:[VNDetectedObjectObservation class]]) {
            return;
        }
        VNDetectedObjectObservation *newObservation = request.results.firstObject;
        // 正确就保存 并准备事件循环
        self.lastObservation = newObservation;
        
        // 在更新 UI 前需要检查置信度
        if (newObservation.confidence < 0.3) {
            // 如果小于 0.3
            // 隐藏 highlightView
            self.highlightView.frame = CGRectZero;
            return;
        }
        
        
        // 计算 视图 rect
        CGRect transformeRect = newObservation.boundingBox;
        transformeRect.origin.y = 1 - transformeRect.origin.y;
        CGRect convertedRect = [self.cameraLayer rectForMetadataOutputRectOfInterest:transformeRect];
        
        // 移动 highLightView
        self.highlightView.frame = convertedRect;
    });

}



#pragma mark - 懒加载属性
- (AVCaptureVideoPreviewLayer *)cameraLayer {
    
    if (!_cameraLayer) {
        _cameraLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    }
    
    return _cameraLayer;
}

- (AVCaptureSession *)captureSession {
    
    if (!_captureSession) {
        _captureSession = [[AVCaptureSession alloc] init];
        _captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
        
        AVCaptureDevice *backCamera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
        
        AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc] initWithDevice:backCamera error:nil];
       
        [_captureSession addInput:input];

    }
    return _captureSession;
}

- (VNSequenceRequestHandler *)visionSequenceHandle {
    
    if (!_visionSequenceHandle) {
        _visionSequenceHandle = [[VNSequenceRequestHandler alloc] init];
    }
    
    return _visionSequenceHandle;

}

@end
