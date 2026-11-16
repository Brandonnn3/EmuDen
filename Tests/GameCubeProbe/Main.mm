// Isolated original-homebrew frontend. Never imports owner games or saves.
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <GameController/GameController.h>
#include <chrono>
#include <thread>
#include "GameCubeCore.h"

@interface ProbeSurface : UIView
@end
@implementation ProbeSurface
+ (Class)layerClass { return CAMetalLayer.class; }
- (void)layoutSubviews {
    [super layoutSubviews];
    self.contentScaleFactor = self.window.screen.scale ?: 2;
    ((CAMetalLayer*)self.layer).drawableSize = CGSizeMake(self.bounds.size.width * self.contentScaleFactor, self.bounds.size.height * self.contentScaleFactor);
    EmuDenGC_Resize();
}
@end

@interface ProbeController : UIViewController
@property ProbeSurface* surface;
@property CAMetalLayer* renderLayer;
@property UILabel* status;
@property UIButton* aButton;
@property dispatch_queue_t hostQueue;
@property dispatch_source_t pump;
@property NSString* userPath;
@property BOOL started;
@property BOOL tested;
@end

@implementation ProbeController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    self.surface = [ProbeSurface new];
    CAMetalLayer* layer = (CAMetalLayer*)self.surface.layer;
    self.renderLayer = layer;
    layer.device = MTLCreateSystemDefaultDevice(); layer.opaque = YES;
    [self.view addSubview:self.surface];
    self.status = [UILabel new]; self.status.text = @"Starting original GameCube demo…";
    self.status.textColor = UIColor.whiteColor;
    self.status.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightMedium];
    [self.view addSubview:self.status];
    self.aButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.aButton setTitle:@"A" forState:UIControlStateNormal];
    self.aButton.titleLabel.font = [UIFont boldSystemFontOfSize:26];
    self.aButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.5 blue:0.45 alpha:1];
    self.aButton.tintColor = UIColor.whiteColor; self.aButton.layer.cornerRadius = 32;
    self.aButton.accessibilityIdentifier = @"probeA";
    [self.aButton addTarget:self action:@selector(buttonDown) forControlEvents:UIControlEventTouchDown];
    [self.aButton addTarget:self action:@selector(buttonUp) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
    [self.view addSubview:self.aButton];
    self.hostQueue = dispatch_queue_create("EmuDen.GameCube.ProbeHost", DISPATCH_QUEUE_SERIAL);
    self.userPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"OriginalGameCubeProbe"];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controllersChanged) name:GCControllerDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controllersChanged) name:GCControllerDidDisconnectNotification object:nil];
    [self controllersChanged];
}
- (BOOL)prefersStatusBarHidden { return YES; }
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    const CGRect bounds = self.view.bounds;
    BOOL controller = GCController.controllers.count > 0 || [NSProcessInfo.processInfo.arguments containsObject:@"--controller-preview"];
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--touch-controls-preview"]) controller = NO;
    BOOL landscape = bounds.size.width > bounds.size.height;
    self.aButton.hidden = controller;
    self.surface.frame = controller ? bounds : (landscape ? CGRectInset(bounds, 124, 0) : CGRectMake(0, 0, bounds.size.width, MAX(0, bounds.size.height - 150)));
    self.aButton.frame = CGRectMake(bounds.size.width - 96, landscape ? bounds.size.height / 2 - 32 : bounds.size.height - 110, 64, 64);
    self.status.frame = CGRectMake(16, 12, MAX(0, bounds.size.width - 32), 24);
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--landscape"]) {
        UIWindowSceneGeometryPreferencesIOS* geometry = [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:UIInterfaceOrientationMaskLandscapeRight];
        [self.view.window.windowScene requestGeometryUpdateWithPreferences:geometry errorHandler:^(NSError* error) { NSLog(@"Probe rotation: %@", error); }];
    }
    if (self.started) return;
    self.started = YES;
    NSString* rom = [NSBundle.mainBundle pathForResource:@"EmuDen-GC-Demo" ofType:@"dol"];
    void* layer = (__bridge void*)self.surface.layer;
    EmuDenGCCallbacks callbacks = {(__bridge void*)self, [](void* context, uint64_t frame, unsigned width, unsigned height) {
        if (frame > 1 && frame % 60 != 0) return;
        ProbeController* controller = (__bridge ProbeController*)context;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!controller.tested) controller.status.text = [NSString stringWithFormat:@"GameCube · Metal · %u × %u · frame %llu", width, height, frame];
        });
    }};
    dispatch_async(self.hostQueue, ^{
        BOOL ok = rom && EmuDenGC_Start(rom.fileSystemRepresentation, self.userPath.fileSystemRepresentation, layer, callbacks);
        if (!ok) { [self finishTest:NO details:@{@"stage":@"start"}]; return; }
        self.pump = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.hostQueue);
        dispatch_source_set_timer(self.pump, DISPATCH_TIME_NOW, 16 * NSEC_PER_MSEC, NSEC_PER_MSEC);
        dispatch_source_set_event_handler(self.pump, ^{ EmuDenGC_Pump(); });
        dispatch_resume(self.pump);
        if ([NSProcessInfo.processInfo.arguments containsObject:@"--self-test"]) [self runOriginalTest];
    });
}
- (void)controllersChanged {
    for (GCController* controller in GCController.controllers) {
        controller.extendedGamepad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput*, float, BOOL pressed) { EmuDenGC_Button(0, pressed); };
    }
    if (GCController.controllers.count == 0) EmuDenGC_Button(0, false);
    [self.view setNeedsLayout];
}
- (void)buttonDown { EmuDenGC_Button(0, true); }
- (void)buttonUp { EmuDenGC_Button(0, false); }
- (void)finishTest:(BOOL)passed details:(NSDictionary*)details {
    NSMutableDictionary* result = [details mutableCopy]; result[@"passed"] = @(passed);
    NSData* data = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:self.userPath withIntermediateDirectories:YES attributes:nil error:nil];
    [data writeToFile:[self.userPath stringByAppendingPathComponent:@"self-test-result.json"] options:NSDataWritingAtomic error:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.tested = YES;
        self.status.text = passed ? @"PASS · native Metal/input/state test" : @"FAIL · see self-test-result.json";
        NSLog(@"GAMECUBE_PROBE_RESULT %@", result);
    });
}
- (void)runOriginalTest {
    auto wait = [](auto condition, int seconds = 15) {
        const auto end = std::chrono::steady_clock::now() + std::chrono::seconds(seconds);
        while (std::chrono::steady_clock::now() < end) {
            EmuDenGC_Pump(); if (condition()) return true;
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
        return false;
    };
    if (!wait([] { return EmuDenGC_DemoStatus().marker == 0x454D5544; }, 90)) { [self finishTest:NO details:@{@"stage":@"PowerPC boot"}]; return; }
    EmuDenGC_Button(0, true);
    if (!wait([] { auto s = EmuDenGC_DemoStatus(); return (s.pad & 0x01000000) && s.first_pixel == 0xB060B090; })) { [self finishTest:NO details:@{@"stage":@"A input"}]; return; }
    EmuDenGC_Pause(true);
    const auto saved = EmuDenGC_DemoStatus();
    NSString* state = [self.userPath stringByAppendingPathComponent:@"original-point.state"];
    if (!EmuDenGC_SaveState(state.fileSystemRepresentation)) { [self finishTest:NO details:@{@"stage":@"save"}]; return; }
    EmuDenGC_Button(0, false); EmuDenGC_Pause(false);
    if (!wait([] { return EmuDenGC_DemoStatus().first_pixel == 0x307030A0; })) { [self finishTest:NO details:@{@"stage":@"release"}]; return; }
    EmuDenGC_Pause(true);
    if (!EmuDenGC_LoadState(state.fileSystemRepresentation)) { [self finishTest:NO details:@{@"stage":@"load"}]; return; }
    const auto restored = EmuDenGC_DemoStatus();
    const BOOL restoredExactly = restored.counter == saved.counter && restored.first_pixel == saved.first_pixel;
    EmuDenGC_Pause(false);
    const BOOL continued = wait([restored] { return EmuDenGC_DemoStatus().counter != restored.counter; });
    BOOL restarted = YES;
    const BOOL checkRestart = [NSProcessInfo.processInfo.arguments containsObject:@"--restart-check"];
    if (checkRestart) {
        EmuDenGC_Stop();
        NSString* rom = [NSBundle.mainBundle pathForResource:@"EmuDen-GC-Demo" ofType:@"dol"];
        restarted = EmuDenGC_Start(rom.fileSystemRepresentation, self.userPath.fileSystemRepresentation,
            (__bridge void*)self.renderLayer, {});
        if (restarted) restarted = wait([] { return EmuDenGC_DemoStatus().marker == 0x454D5544; }, 90);
        EmuDenGC_Stop();
        dispatch_source_cancel(self.pump);
        self.pump = nil;
    }
    [self finishTest:restoredExactly && continued && restarted details:@{@"stage":@"complete", @"savedCounter":@(saved.counter), @"restoredCounter":@(restored.counter), @"continued":@(continued), @"restartChecked":@(checkRestart), @"restarted":@(restarted), @"scope":@"Original VI/SI fixture; no GX/audio/native-card/phone claim"}];
}
@end

@interface ProbeSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow* window;
@end
@implementation ProbeSceneDelegate
- (void)scene:(UIScene*)scene willConnectToSession:(UISceneSession*)session options:(UISceneConnectionOptions*)options {
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene*)scene];
    self.window.rootViewController = [ProbeController new];
    [self.window makeKeyAndVisible];
}
@end
@interface ProbeDelegate : UIResponder <UIApplicationDelegate>
@end
@implementation ProbeDelegate
@end
int main(int argc, char** argv) { @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(ProbeDelegate.class)); } }
