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
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *cameraLayer;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) VNSequenceRequestHandler *visionSequenceHandle;
@property (nonatomic, strong) VNDetectedObjectObservation *lastObservation;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 让 camera 实时获取的视频出现在屏幕上
    [self.cameraView.layer addSublayer:self.cameraLayer];
    
    // 注册接收相机缓冲区
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [videoOutput setSampleBufferDelegate:self queue: dispatch_queue_create("MyQueue", NULL)];
    [self.captureSession addOutput:videoOutput];
    // 让 session 开始
    [self.captureSession startRunning];
    
}

- (void)viewDidLayoutSubviews {
    
    [super viewDidLayoutSubviews];
    
    // 让 layer 获得正确的大小
    self.cameraLayer.frame = self.cameraView.bounds;
    
    
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
    VNTrackObjectRequest *request = [[VNTrackObjectRequest alloc] initWithDetectedObjectObservation:self.lastObservation completionHandler:nil];
    request.trackingLevel = VNRequestTrackingLevelAccurate;
    
    // 执行请求
    NSError *error = nil;
    [self.visionSequenceHandle performRequests:@[request] onCVPixelBuffer:pixelBuffer error:&error];
    if (error) {
        NSLog(@"error: %@", error);
    }
    
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
