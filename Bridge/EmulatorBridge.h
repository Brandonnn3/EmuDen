#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@interface EmulatorBridge : NSObject
@property (nonatomic, copy, nullable) void (^frameHandler)(UIImage *image);
@property (nonatomic, copy, nullable) void (^messageHandler)(NSString *message);
@property (nonatomic, copy, nullable) void (^statisticsHandler)(double fps);
@property (nonatomic, copy, nullable) void (^performanceHandler)(NSDictionary<NSString *, NSNumber *> *sample);
@property (nonatomic, copy, nullable) void (^shaderProgressHandler)(NSString * _Nullable message, double progress);
- (void)configureResolution:(NSInteger)resolution asyncShaders:(BOOL)asyncShaders textureSampling:(NSString *)sampling prepareShaders:(BOOL)prepare;
- (void)startROM:(NSString *)path saveDirectory:(NSString *)directory completion:(void (^)(NSString * _Nullable error))completion;
- (void)setButton:(unsigned)button pressed:(BOOL)pressed;
- (void)setAnalogX:(float)x y:(float)y;
- (void)setTouchX:(float)x y:(float)y pressed:(BOOL)pressed;
- (void)setPaused:(BOOL)paused;
- (void)captureStateWithCompletion:(void (^)(NSData * _Nullable data, NSString * _Nullable error))completion;
- (void)restoreState:(NSData *)data completion:(void (^)(NSString * _Nullable error))completion;
- (void)stopWithCompletion:(void (^)(void))completion;
@end
NS_ASSUME_NONNULL_END
