#import "EmulatorBridge.h"
#import <AVFoundation/AVFoundation.h>
#import <TargetConditionals.h>
#include "libretro.h"
#include "VulkanVideo.h"
#include <dlfcn.h>
#include <atomic>
#include <map>
#include <string>
#include <mutex>
#include <array>
#include <algorithm>
#include <cstdarg>
#include <stdexcept>
#include <sys/utsname.h>
#include "InputLatch.h"

struct CoreAPI {
    void *handle = nullptr;
    void (*retro_init)(); void (*retro_deinit)();
    unsigned (*retro_api_version)();
    void (*retro_set_environment)(retro_environment_t);
    void (*retro_set_video_refresh)(retro_video_refresh_t);
    void (*retro_set_audio_sample)(retro_audio_sample_t);
    void (*retro_set_audio_sample_batch)(retro_audio_sample_batch_t);
    void (*retro_set_input_poll)(retro_input_poll_t);
    void (*retro_set_input_state)(retro_input_state_t);
    bool (*retro_load_game)(const retro_game_info *);
    void (*retro_get_system_av_info)(retro_system_av_info *);
    void (*retro_run)(); void (*retro_unload_game)();
    size_t (*retro_serialize_size)();
    bool (*retro_serialize)(void *, size_t);
    bool (*retro_unserialize)(const void *, size_t);
};
static CoreAPI api;
static EmulatorBridge *active = nil;
static std::mutex logMutex;
static FILE *logFile = nullptr;

@interface EmulatorBridge () {
@public
    std::map<std::string, std::string> _options;
    std::string _savePath;
    InputLatch _input;
    std::atomic_int _analogX, _analogY;
    std::atomic_bool _paused, _framePending;
    std::atomic_bool _fatal;
    std::mutex _audioMutex;
    std::array<float, 65536> _audioRing;
    size_t _audioRead, _audioWrite;
    BOOL _initialized, _loaded;
    std::unique_ptr<VulkanVideo> _gpu;
    NSString *_lastError;
    NSString *_logCopyPath;
    dispatch_queue_t _queue;
    dispatch_source_t _timer;
    AVAudioEngine *_audioEngine;
    AVAudioSourceNode *_audioSource;
    CFTimeInterval _statsStart;
    std::atomic_uint _frameCount;
    double _runSeconds, _readbackSeconds, _worstFrame;
    unsigned _benchmarkFrames, _slowFrames;
    NSInteger _resolution;
    BOOL _asyncShaders, _prepareShaders, _optionsChanged;
    std::string _sampling;
    double _sampleSeconds, _sampleWorst, _nominalFPS;
    unsigned _sampleFrames;
}
- (void)receiveMessage:(NSString *)message;
- (void)receiveFrame:(const void *)data width:(unsigned)width height:(unsigned)height pitch:(size_t)pitch BGRA:(BOOL)bgra;
- (void)startAudio:(double)rate;
- (void)resetStatistics;
@end

static void CoreLog(enum retro_log_level level, const char *format, ...) {
    if (level < RETRO_LOG_INFO) return;
    char buffer[4096]; va_list args; va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args); va_end(args);
    std::lock_guard<std::mutex> lock(logMutex);
    if (logFile) {
        fprintf(logFile, "%s", buffer);
        if (level >= RETRO_LOG_WARN || !strncmp(buffer, "PERF:", 5)) fflush(logFile);
    }
}
static bool Environment(unsigned command, void *data) {
    if (!active) return false;
    if (active->_gpu && active->_gpu->environment(command, data)) return true;
    switch (command) {
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
            *(const char **)data = active->_savePath.c_str(); return true;
        case RETRO_ENVIRONMENT_GET_LOG_INTERFACE:
            ((retro_log_callback *)data)->log = CoreLog; return true;
        case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION: *(unsigned *)data = 2; return true;
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2: {
            auto *options = (retro_core_options_v2 *)data;
            for (auto *o = options->definitions; o && o->key; ++o)
                if (!active->_options.count(o->key)) active->_options[o->key] = o->default_value ? o->default_value : o->values[0].value;
            return true;
        }
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS: {
            for (auto *o = (retro_core_option_definition *)data; o && o->key; ++o)
                if (!active->_options.count(o->key)) active->_options[o->key] = o->default_value ? o->default_value : o->values[0].value;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_VARIABLE: {
            auto *v = (retro_variable *)data;
            auto it = active->_options.find(v->key);
            v->value = it == active->_options.end() ? nullptr : it->second.c_str(); return v->value != nullptr;
        }
        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
            *(bool *)data = active->_optionsChanged; active->_optionsChanged = NO; return true;
        case RETRO_ENVIRONMENT_GET_JIT_CAPABLE: *(bool *)data = false; return true;
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: return *(retro_pixel_format *)data == RETRO_PIXEL_FORMAT_XRGB8888;
        case RETRO_ENVIRONMENT_GET_CAN_DUPE: *(bool *)data = true; return true;
        case RETRO_ENVIRONMENT_SET_MESSAGE:
            [active receiveMessage:[NSString stringWithUTF8String:((retro_message *)data)->msg]]; return true;
        case RETRO_ENVIRONMENT_GET_MESSAGE_INTERFACE_VERSION: *(unsigned *)data = 0; return true;
        case RETRO_ENVIRONMENT_SHUTDOWN:
            active->_paused = true; [active receiveMessage:@"The emulated application has stopped."]; return true;
        case RETRO_ENVIRONMENT_SET_GEOMETRY:
        case RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO:
        case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
        case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
        case RETRO_ENVIRONMENT_SET_MEMORY_MAPS:
        case RETRO_ENVIRONMENT_SET_SERIALIZATION_QUIRKS:
        case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME: return true;
        case RETRO_ENVIRONMENT_GET_AUDIO_VIDEO_ENABLE: *(int *)data = 3; return true;
        case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS: return true;
        default: return false;
    }
}
static void Video(const void *data, unsigned w, unsigned h, size_t pitch) {
    if (data == RETRO_HW_FRAME_BUFFER_VALID && active && active->_gpu) {
        const double start = CACurrentMediaTime();
        const bool asynchronous = active->_gpu->enqueueFrame(w, h);
        const auto frame = asynchronous ? VulkanVideo::Frame{nullptr, false} : active->_gpu->readFrame(w, h);
        active->_readbackSeconds += CACurrentMediaTime() - start;
        if (frame.data) [active receiveFrame:frame.data width:w height:h pitch:w * 4 BGRA:frame.bgra];
    } else [active receiveFrame:data width:w height:h pitch:pitch BGRA:YES];
}
static size_t Audio(const int16_t *data, size_t frames) {
    if (!active) return frames;
    std::lock_guard<std::mutex> lock(active->_audioMutex);
    for (size_t i = 0; i < frames * 2; i++) {
        size_t next = (active->_audioWrite + 1) % active->_audioRing.size();
        if (next == active->_audioRead) active->_audioRead = (active->_audioRead + 2) % active->_audioRing.size();
        active->_audioRing[active->_audioWrite] = data[i] / 32768.0f;
        active->_audioWrite = next;
    }
    return frames;
}
static void AudioSample(int16_t l, int16_t r) { int16_t samples[] = {l,r}; Audio(samples, 1); }
static void PollInput() { if (active) active->_input.poll(); }
static int16_t Input(unsigned port, unsigned device, unsigned index, unsigned id) {
    if (!active || port != 0) return 0;
    device &= RETRO_DEVICE_MASK;
    if (device == RETRO_DEVICE_JOYPAD) {
        unsigned bits = active->_input.buttons();
        if (id == RETRO_DEVICE_ID_JOYPAD_MASK) return (int16_t)bits;
        return id < 16 ? ((bits >> id) & 1) : 0;
    }
    if (device == RETRO_DEVICE_ANALOG && index == RETRO_DEVICE_INDEX_ANALOG_LEFT)
        return id == RETRO_DEVICE_ID_ANALOG_X ? active->_analogX.load() : active->_analogY.load();
    if (device == RETRO_DEVICE_POINTER) {
        const auto touch = active->_input.touch();
        if (id == RETRO_DEVICE_ID_POINTER_X) return touch.x;
        if (id == RETRO_DEVICE_ID_POINTER_Y) return touch.y;
        if (id == RETRO_DEVICE_ID_POINTER_PRESSED) return touch.down;
        if (id == RETRO_DEVICE_ID_POINTER_COUNT) return touch.down ? 1 : 0;
    }
    return 0;
}

@implementation EmulatorBridge
- (instancetype)init {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("app.emulator.core",
            dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0));
        _analogX = 0; _analogY = 0;
        _paused = false; _framePending = false; _fatal = false;
        _audioRead = _audioWrite = 0;
        _resolution = 1; _asyncShaders = YES; _prepareShaders = NO; _sampling = "GameControlled";
        _optionsChanged = NO; _nominalFPS = 60; _frameCount = 0;
    }
    return self;
}
- (void)configureResolution:(NSInteger)resolution asyncShaders:(BOOL)asyncShaders textureSampling:(NSString *)sampling prepareShaders:(BOOL)prepare {
    const NSInteger factor = std::clamp<NSInteger>(resolution, 1, 3);
    NSString *mode = [@[@"GameControlled", @"NearestNeighbor", @"Linear"] containsObject:sampling] ? sampling : @"GameControlled";
    dispatch_async(_queue, ^{
        const bool changed = self->_resolution != factor || self->_asyncShaders != asyncShaders || self->_sampling != mode.UTF8String;
        if (changed && self->_loaded && !self->_fatal) {
            try { self->_gpu->finishFrames(); }
            catch (...) { self->_fatal = true; [self receiveMessage:@"Graphics could not finish updating. Reopen the game to continue."]; return; }
            self->_options["citra_resolution_factor"] = std::to_string(factor);
            self->_options["citra_async_shader_compilation"] = asyncShaders ? "enabled" : "disabled";
            self->_options["citra_texture_sampling"] = mode.UTF8String;
            self->_optionsChanged = YES;
            CoreLog(RETRO_LOG_INFO, "GRAPHICS: live resolution=%ldx, sampling=%s, async=%s\n", (long)factor, mode.UTF8String, asyncShaders ? "on" : "off");
        }
        self->_resolution = factor; self->_asyncShaders = asyncShaders;
        self->_sampling = mode.UTF8String; self->_prepareShaders = prepare;
    });
}
- (void)startROM:(NSString *)path saveDirectory:(NSString *)directory completion:(void (^)(NSString *))completion {
    dispatch_async(_queue, ^{
        @autoreleasepool {
            if (active) { dispatch_async(dispatch_get_main_queue(), ^{ completion(@"Another emulation session is still closing. Try again in a moment."); }); return; }
            NSString *error = nil;
            if (!api.handle) {
                NSString *core = [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"Azahar.framework/Azahar"];
                api.handle = dlopen(core.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
                if (!api.handle) error = [NSString stringWithFormat:@"Could not load Azahar: %s", dlerror()];
#define LOAD(name) if (!error) { api.name = (decltype(api.name))dlsym(api.handle, #name); if (!api.name) error = @"The embedded core is missing " #name; }
                LOAD(retro_init) LOAD(retro_deinit) LOAD(retro_api_version)
                LOAD(retro_set_environment) LOAD(retro_set_video_refresh)
                LOAD(retro_set_audio_sample) LOAD(retro_set_audio_sample_batch)
                LOAD(retro_set_input_poll) LOAD(retro_set_input_state)
                LOAD(retro_load_game) LOAD(retro_get_system_av_info) LOAD(retro_run) LOAD(retro_unload_game)
                LOAD(retro_serialize_size) LOAD(retro_serialize) LOAD(retro_unserialize)
#undef LOAD
                if (!error && api.retro_api_version() != RETRO_API_VERSION) error = @"The embedded core uses an unsupported API version.";
                if (error && api.handle) { dlclose(api.handle); api = CoreAPI{}; }
            }
            if (!error) {
                active = self;
                self->_savePath = directory.UTF8String;
                NSString *metal = [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"MoltenVK.framework/MoltenVK"];
                bool pipeline = true;
#if TARGET_OS_SIMULATOR
                pipeline = ![NSProcessInfo.processInfo.environment[@"EMUDEN_TEST_GPU_PIPELINE"] isEqualToString:@"off"];
#endif
                VulkanVideo::FrameHandler handler;
                if (pipeline) {
                    __weak EmulatorBridge *weakBridge = self;
                    handler = [weakBridge](VulkanVideo::Frame frame, unsigned width, unsigned height) {
                        @autoreleasepool {
                            EmulatorBridge *bridge = weakBridge;
                            if (bridge) [bridge receiveFrame:frame.data width:width height:height pitch:width * 4 BGRA:frame.bgra];
                        }
                    };
                }
                self->_gpu = std::make_unique<VulkanVideo>(metal.fileSystemRepresentation, std::move(handler));
                self->_options = {{"citra_graphics_api","Vulkan"}, {"citra_use_cpu_jit","disabled"}, {"citra_use_fastinterp","enabled"},
                    {"citra_use_shader_jit","disabled"}, {"citra_use_hw_shader","enabled"},
                    {"citra_resolution_factor","1"}, {"citra_layout_option","default"},
                    {"citra_use_libretro_save_path","LibRetro Default"}, {"citra_enable_motion","disabled"},
                    {"citra_enable_mouse_touchscreen","disabled"}, {"citra_enable_touch_touchscreen","enabled"}};
                self->_options["citra_resolution_factor"] = std::to_string(self->_resolution);
                self->_options["citra_async_shader_compilation"] = self->_asyncShaders ? "enabled" : "disabled";
                self->_options["citra_texture_sampling"] = self->_sampling;
                self->_options["emuden_prepare_cached_shaders"] = self->_prepareShaders ? "enabled" : "disabled";
                self->_options["citra_use_disk_shader_cache"] = "enabled";
#if TARGET_OS_SIMULATOR
                NSString *shaderMode = NSProcessInfo.processInfo.environment[@"EMUDEN_TEST_ASYNC_SHADERS"];
                if ([shaderMode isEqualToString:@"on"] || [shaderMode isEqualToString:@"off"])
                    self->_options["citra_async_shader_compilation"] = [shaderMode isEqualToString:@"on"] ? "enabled" : "disabled";
#endif
                {
                    std::lock_guard<std::mutex> lock(logMutex);
                    NSString *logs = [directory stringByAppendingPathComponent:@"Logs"];
                    [NSFileManager.defaultManager createDirectoryAtPath:logs withIntermediateDirectories:YES attributes:nil error:nil];
                    self->_logCopyPath = [logs stringByAppendingPathComponent:[path.lastPathComponent stringByAppendingString:@".log"]];
                    NSString *current = [directory stringByAppendingPathComponent:@"azahar-session.log"];
                    NSString *previous = [directory stringByAppendingPathComponent:@"azahar-session-previous.log"];
                    rename(current.fileSystemRepresentation, previous.fileSystemRepresentation);
                    logFile = fopen(current.fileSystemRepresentation, "w");
                }
                try {
                    api.retro_set_environment(Environment); api.retro_set_video_refresh(Video);
                    api.retro_set_audio_sample(AudioSample); api.retro_set_audio_sample_batch(Audio);
                    api.retro_set_input_poll(PollInput); api.retro_set_input_state(Input);
                    api.retro_init(); self->_initialized = YES;
                    CoreLog(RETRO_LOG_INFO, "EmuDen shaders: async=%s, disk_cache=enabled; CPU=FastInterp; CPU/shader JIT disabled\n",
                            self->_options["citra_async_shader_compilation"].c_str());
                    CoreLog(RETRO_LOG_INFO, "EmuDen graphics: resolution=%sx native, GPU readback=%s\n", self->_options["citra_resolution_factor"].c_str(), pipeline ? "asynchronous, shared-image completion guard" : "synchronous");
                    CoreLog(RETRO_LOG_INFO, "PERF note: GPU readback reports frontend CPU submission/blocking time, not GPU execution time.\n");
                    struct utsname machine{}; uname(&machine);
#if TARGET_OS_SIMULATOR
                    CoreLog(RETRO_LOG_INFO, "Benchmark environment: iOS Simulator model=%s host=%s; timings use the Mac CPU/GPU\n",
                            NSProcessInfo.processInfo.environment[@"SIMULATOR_MODEL_IDENTIFIER"].UTF8String ?: "unknown", machine.machine);
#else
                    CoreLog(RETRO_LOG_INFO, "Benchmark environment: physical iOS device model=%s\n", machine.machine);
#endif
                    retro_game_info info{}; info.path = path.fileSystemRepresentation;
                    self->_loaded = api.retro_load_game(&info);
                    if (!self->_loaded) error = @"Azahar could not boot this game. Check that it is decrypted and review the session log in Files → EmuDen → Saves.";
                    else {
                        if (!self->_gpu->requested()) throw std::runtime_error("The core did not enable the GPU renderer");
                        self->_gpu->initialize();
                        self->_gpu->finishFrames();
                        CoreLog(RETRO_LOG_INFO, "Frontend GPU: %s (MoltenVK)\n", self->_gpu->deviceName().c_str());
                        if (self->_fatal) throw std::runtime_error(self->_lastError.UTF8String ?: "The core could not initialize the game");
                        retro_system_av_info av{}; api.retro_get_system_av_info(&av);
                        [self startAudio:av.timing.sample_rate];
                        self->_nominalFPS = std::max(1.0, av.timing.fps);
                        [self resetStatistics];
                        self->_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self->_queue);
                        uint64_t interval = (uint64_t)(NSEC_PER_SEC / std::max(1.0, av.timing.fps));
                        dispatch_source_set_timer(self->_timer, dispatch_time(DISPATCH_TIME_NOW, 0), interval, NSEC_PER_MSEC);
                        __weak EmulatorBridge *weakSelf = self;
                        dispatch_source_set_event_handler(self->_timer, ^{
                            EmulatorBridge *strongSelf = weakSelf;
                            if (!strongSelf || strongSelf->_paused || strongSelf->_fatal) return;
                            @autoreleasepool {
                                try {
                                    const double start = CACurrentMediaTime();
                                    api.retro_run();
                                    const double duration = CACurrentMediaTime() - start;
                                    strongSelf->_sampleSeconds += duration;
                                    strongSelf->_sampleWorst = std::max(strongSelf->_sampleWorst, duration);
                                    ++strongSelf->_sampleFrames;
                                    const double elapsed = CACurrentMediaTime() - strongSelf->_statsStart;
                                    if (elapsed >= 1) {
                                        const double fps = strongSelf->_frameCount.exchange(0) / elapsed;
                                        NSDictionary *sample = @{@"fps": @(fps), @"coreFPS": @(strongSelf->_sampleFrames / elapsed),
                                            @"targetFPS": @(strongSelf->_nominalFPS), @"meanMS": @(strongSelf->_sampleSeconds * 1000 / strongSelf->_sampleFrames),
                                            @"worstMS": @(strongSelf->_sampleWorst * 1000), @"thermal": @((NSInteger)NSProcessInfo.processInfo.thermalState),
                                            @"resolution": @(strongSelf->_resolution)};
                                        strongSelf->_statsStart = CACurrentMediaTime();
                                        strongSelf->_sampleFrames = 0; strongSelf->_sampleSeconds = 0; strongSelf->_sampleWorst = 0;
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            if (strongSelf.statisticsHandler) strongSelf.statisticsHandler(fps);
                                            if (strongSelf.performanceHandler) strongSelf.performanceHandler(sample);
                                        });
                                    }
                                    strongSelf->_runSeconds += duration;
                                    strongSelf->_worstFrame = std::max(strongSelf->_worstFrame, duration);
                                    if (duration > 1.0 / 30) ++strongSelf->_slowFrames;
                                    if (++strongSelf->_benchmarkFrames == 120) {
                                        CoreLog(RETRO_LOG_INFO, "PERF: 120 core frames, core+display %.2f ms/frame, GPU readback %.2f ms/frame, thermal=%ld\n",
                                                strongSelf->_runSeconds * 1000 / 120, strongSelf->_readbackSeconds * 1000 / 120,
                                                (long)NSProcessInfo.processInfo.thermalState);
                                        strongSelf->_runSeconds = strongSelf->_readbackSeconds = 0;
                                        CoreLog(RETRO_LOG_INFO, "PERF: worst %.2f ms, %u frames over 33 ms in last 120\n",
                                                strongSelf->_worstFrame * 1000, strongSelf->_slowFrames);
                                        strongSelf->_worstFrame = 0; strongSelf->_slowFrames = 0;
                                        strongSelf->_benchmarkFrames = 0;
                                    }
                                }
                                catch (const std::exception &e) { strongSelf->_fatal = true; [strongSelf receiveMessage:[NSString stringWithFormat:@"Core error: %s", e.what()]]; }
                                catch (...) { strongSelf->_fatal = true; [strongSelf receiveMessage:@"An unexpected error stopped the core."]; }
                            }
                        });
                        dispatch_resume(self->_timer);
                    }
                } catch (const std::exception &e) { error = [NSString stringWithFormat:@"Azahar initialization failed: %s", e.what()]; }
                catch (...) { error = @"Azahar initialization failed."; }
            }
            dispatch_async(dispatch_get_main_queue(), ^{ completion(error); });
        }
    });
}
- (void)receiveMessage:(NSString *)message {
    if ([message isEqualToString:@"EMUDEN_SHADER_READY"]) {
        dispatch_async(dispatch_get_main_queue(), ^{ if (self.shaderProgressHandler) self.shaderProgressHandler(nil, -1); }); return;
    }
    if ([message hasPrefix:@"EMUDEN_SHADER_PROGRESS:"]) {
        NSArray<NSString *> *parts = [message componentsSeparatedByString:@":"];
        if (parts.count == 4 && message.length <= 256) {
            const double current = parts[1].doubleValue, total = parts[2].doubleValue;
            const double progress = total > 0 ? std::clamp(current / total, 0.0, 1.0) : -1;
            NSString *stage = parts[3];
            dispatch_async(dispatch_get_main_queue(), ^{ if (self.shaderProgressHandler) self.shaderProgressHandler(stage, progress); });
        }
        return;
    }
    if ([message containsString:@"Fatal"] || [message containsString:@"system archive"] ||
        [message hasPrefix:@"Failed to"] || [message hasPrefix:@"Error while loading"] ||
        [message containsString:@"must be decrypted"]) {
        _fatal = true; _lastError = message;
    }
    dispatch_async(dispatch_get_main_queue(), ^{ if (self.messageHandler) self.messageHandler(message); });
}
- (void)receiveFrame:(const void *)data width:(unsigned)w height:(unsigned)h pitch:(size_t)pitch BGRA:(BOOL)bgra {
    if (!data || data == RETRO_HW_FRAME_BUFFER_VALID || !w || !h || w > 4096 || h > 4096 || pitch < w * 4) return;
    _frameCount++;
    if (_framePending.exchange(true)) return;
    CFDataRef copy = CFDataCreate(kCFAllocatorDefault, (const UInt8 *)data, pitch * h);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(copy);
    CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo format = bgra ? kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst
                               : kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipLast;
    CGImageRef cg = CGImageCreate(w, h, 8, 32, pitch, color, format, provider, nullptr, false, kCGRenderingIntentDefault);
    UIImage *image = cg ? [UIImage imageWithCGImage:cg] : nil;
    if (cg) CGImageRelease(cg); CGColorSpaceRelease(color); CGDataProviderRelease(provider); CFRelease(copy);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (image && self.frameHandler) self.frameHandler(image);
        self->_framePending = false;
    });
}
- (void)startAudio:(double)rate {
    NSError *error = nil;
    [AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryPlayback error:&error];
    [AVAudioSession.sharedInstance setActive:YES error:&error];
    _audioEngine = [AVAudioEngine new];
    AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:rate channels:2];
    __weak EmulatorBridge *weakSelf = self;
    _audioSource = [[AVAudioSourceNode alloc] initWithFormat:format renderBlock:^OSStatus(BOOL *silent, const AudioTimeStamp *timestamp, AVAudioFrameCount frames, AudioBufferList *list) {
        EmulatorBridge *s = weakSelf;
        for (UInt32 channel = 0; channel < list->mNumberBuffers; channel++) memset(list->mBuffers[channel].mData, 0, list->mBuffers[channel].mDataByteSize);
        if (!s || s->_paused) return noErr;
        // Never block the real-time audio thread while the core is submitting samples.
        std::unique_lock<std::mutex> lock(s->_audioMutex, std::try_to_lock);
        if (!lock.owns_lock()) return noErr;
        for (UInt32 i = 0; i < frames; i++) {
            if (s->_audioRead == s->_audioWrite) break;
            for (UInt32 channel = 0; channel < 2; channel++) {
                float sample = s->_audioRing[s->_audioRead];
                s->_audioRead = (s->_audioRead + 1) % s->_audioRing.size();
                if (channel < list->mNumberBuffers) ((float *)list->mBuffers[channel].mData)[i] = sample;
            }
        }
        return noErr;
    }];
    [_audioEngine attachNode:_audioSource];
    [_audioEngine connect:_audioSource to:_audioEngine.mainMixerNode format:format];
    if (![_audioEngine startAndReturnError:&error]) [self receiveMessage:[@"Audio unavailable: " stringByAppendingString:error.localizedDescription]];
}
- (void)setButton:(unsigned)button pressed:(BOOL)pressed {
    _input.setButton(button, pressed);
}
- (void)setAnalogX:(float)x y:(float)y {
    _analogX = (int)(std::clamp(x, -1.0f, 1.0f) * 32767); _analogY = (int)(std::clamp(y, -1.0f, 1.0f) * 32767);
}
- (void)setTouchX:(float)x y:(float)y pressed:(BOOL)pressed {
    _input.setTouch((int)(std::clamp(x, 0.0f, 1.0f) * 65534 - 32767),
                    (int)(std::clamp(y, 0.0f, 1.0f) * 65534 - 32767), pressed);
}
- (void)setPaused:(BOOL)paused {
    if (paused) _paused = true;
    else dispatch_async(_queue, ^{ [self resetStatistics]; self->_paused = false; });
    if (paused) { _input.clear(); _analogX = 0; _analogY = 0; }
    std::lock_guard<std::mutex> lock(_audioMutex); _audioRead = _audioWrite = 0;
}
- (void)resetStatistics {
    _statsStart = CACurrentMediaTime(); _frameCount = 0;
    _sampleFrames = 0; _sampleSeconds = 0; _sampleWorst = 0;
}
- (void)captureStateWithCompletion:(void (^)(NSData *, NSString *))completion {
    dispatch_async(_queue, ^{
        @autoreleasepool {
            NSString *error = nil; NSData *data = nil;
            try {
                if (!self->_loaded || self->_fatal) error = @"The game is not ready to save a state.";
                else {
                    if (self->_gpu) self->_gpu->finishFrames();
                    size_t size = api.retro_serialize_size();
                    if (size < 256 || size > 256 * 1024 * 1024) error = @"The core could not capture this state. Your previous save is unchanged.";
                    else {
                        NSMutableData *buffer = [NSMutableData dataWithLength:size];
                        if (buffer && api.retro_serialize(buffer.mutableBytes, size)) data = buffer;
                        else error = @"State capture failed. Your previous save is unchanged.";
                    }
                }
            } catch (...) { error = @"The core could not capture this state. Use the game's own save menu and try again."; }
            CoreLog(error ? RETRO_LOG_ERROR : RETRO_LOG_INFO, "STATE: capture %s (%lu bytes)\n", error ? "failed" : "complete", (unsigned long)data.length);
            dispatch_async(dispatch_get_main_queue(), ^{ completion(data, error); });
        }
    });
}
- (void)restoreState:(NSData *)data completion:(void (^)(NSString *))completion {
    dispatch_async(_queue, ^{
        NSString *error = nil;
        try {
            if (!self->_loaded || self->_fatal) error = @"The game is not ready to load a state.";
            else {
                if (self->_gpu) self->_gpu->finishFrames();
                if (data.length < 256 || data.length > 256 * 1024 * 1024 ||
                     !api.retro_unserialize(data.bytes, data.length))
                error = @"This state could not be loaded. It may belong to a different game or core version. Your files are unchanged.";
            }
        } catch (...) {
            self->_fatal = true;
            error = @"The core could not restore this state. Restart the game to continue from an in-game save.";
        }
        self->_input.clear(); self->_analogX = 0; self->_analogY = 0;
        { std::lock_guard<std::mutex> lock(self->_audioMutex); self->_audioRead = self->_audioWrite = 0; }
        [self resetStatistics];
        CoreLog(error ? RETRO_LOG_ERROR : RETRO_LOG_INFO, "STATE: restore %s\n", error ? "failed" : "complete");
        dispatch_async(dispatch_get_main_queue(), ^{ completion(error); });
    });
}
- (void)stopWithCompletion:(void (^)(void))completion {
    _paused = true;
    if (_timer) { dispatch_source_cancel(_timer); _timer = nil; }
    dispatch_async(_queue, ^{
        if (self->_timer) { dispatch_source_cancel(self->_timer); self->_timer = nil; }
        [self->_audioEngine stop]; self->_audioEngine = nil; self->_audioSource = nil;
        try { if (self->_gpu) self->_gpu->finishFrames(); }
        catch (...) { CoreLog(RETRO_LOG_WARN, "GPU transfer could not drain; attempting core teardown.\n"); }
        try {
            if (self->_loaded) api.retro_unload_game();
            if (self->_gpu) self->_gpu->destroyContext();
            if (self->_initialized) api.retro_deinit();
        }
        catch (...) { /* Core teardown cannot recover a C++ failure; retain log for diagnosis. */ }
        self->_gpu.reset();
        self->_loaded = self->_initialized = NO;
        if (active == self) {
            active = nil;
            { std::lock_guard<std::mutex> lock(logMutex); if (logFile) { fclose(logFile); logFile = nullptr; } }
            if (self->_logCopyPath) {
                NSString *current = [@(self->_savePath.c_str()) stringByAppendingPathComponent:@"azahar-session.log"];
                NSData *log = [NSData dataWithContentsOfFile:current];
                [log writeToFile:self->_logCopyPath options:NSDataWritingAtomic error:nil];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(); });
    });
}
@end
