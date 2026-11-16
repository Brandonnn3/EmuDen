#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/CAMetalLayer.h>
NS_ASSUME_NONNULL_BEGIN
@interface EmulatorBridge : NSObject
@property (nonatomic, copy, nullable) void (^frameHandler)(UIImage *image);
@property (nonatomic, copy, nullable) void (^messageHandler)(NSString *message);
@property (nonatomic, copy, nullable) void (^statisticsHandler)(double fps);
@property (nonatomic, copy, nullable) void (^performanceHandler)(NSDictionary<NSString *, NSNumber *> *sample);
@property (nonatomic, copy, nullable) void (^shaderProgressHandler)(NSString * _Nullable message, double progress);
@property (nonatomic, copy, nullable) void (^nativeFrameHandler)(NSUInteger totalFrames);
@property (nonatomic, readonly) CAMetalLayer *nativeLayer;
#if TARGET_OS_SIMULATOR
@property (nonatomic, copy, nullable) void (^nativeDiagnosticHandler)(NSDictionary<NSString *, NSNumber *> *status);
@property (nonatomic, readonly) NSUInteger motionTestStatus;
@property (nonatomic, readonly) NSString *playStationInputStatus;
#endif
- (void)nativeSurfaceChanged;
- (void)configureResolution:(NSInteger)resolution asyncShaders:(BOOL)asyncShaders textureSampling:(NSString *)sampling prepareShaders:(BOOL)prepare;
- (void)configurePlayStationResolution:(NSInteger)resolution dithering:(BOOL)dithering textureFix:(BOOL)textureFix;
- (void)configureGameCubeResolution:(NSInteger)resolution filtering:(NSInteger)filtering anisotropy:(NSInteger)anisotropy;
- (void)setPresentationRate:(NSUInteger)rate;
- (void)setPlaybackSpeed:(double)speed;
- (void)setMotionHardwareAvailable:(BOOL)available;
- (void)setMotionEnabled:(BOOL)enabled;
- (void)setMotionAccelerationX:(float)x y:(float)y z:(float)z rotationX:(float)rx rotationY:(float)ry rotationZ:(float)rz;
- (void)startROM:(NSString *)path saveDirectory:(NSString *)directory systemDirectory:(NSString *)system core:(NSString *)core completion:(void (^)(NSString * _Nullable error))completion;
- (void)setButton:(unsigned)button pressed:(BOOL)pressed;
- (void)setAnalogX:(float)x y:(float)y;
- (void)setRightAnalogX:(float)x y:(float)y;
- (void)setPlayStationAnalogEnabled:(BOOL)enabled;
- (void)setGameCubeCStickX:(float)x y:(float)y;
- (void)setGameCubeTriggerLeft:(float)left right:(float)right;
- (void)setTouchX:(float)x y:(float)y pressed:(BOOL)pressed;
- (void)setPaused:(BOOL)paused;
- (void)captureStateWithCompletion:(void (^)(NSData * _Nullable data, NSString * _Nullable error))completion;
- (void)restoreState:(NSData *)data completion:(void (^)(NSString * _Nullable error))completion;
- (void)stopWithCompletion:(void (^)(void))completion;
@end
NS_ASSUME_NONNULL_END
