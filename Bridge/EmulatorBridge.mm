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
#include <vector>
#include <algorithm>
#include <cstdarg>
#include <stdexcept>
#include <sys/utsname.h>
#include "InputLatch.h"
#include "MotionInput.h"
#include "FrameDelivery.h"
#include "GameCubeCore.h"

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
    void (*retro_set_controller_port_device)(unsigned, unsigned);
    int (*padToggleAnalog)(unsigned);
    bool (*retro_load_game)(const retro_game_info *);
    void (*retro_get_system_av_info)(retro_system_av_info *);
    void (*retro_run)(); void (*retro_unload_game)();
    size_t (*retro_serialize_size)();
    bool (*retro_serialize)(void *, size_t);
    bool (*retro_unserialize)(const void *, size_t);
};
static CoreAPI api;
static std::map<std::string, CoreAPI> coreAPIs;
static EmulatorBridge *active = nil;
static std::mutex logMutex;
static FILE *logFile = nullptr;

struct GameCubeAPI {
    void* handle = nullptr;
    decltype(&EmuDenGC_Start) start = nullptr;
    decltype(&EmuDenGC_Pump) pump = nullptr;
    decltype(&EmuDenGC_Resize) resize = nullptr;
    decltype(&EmuDenGC_ConfigureGraphics) configureGraphics = nullptr;
    decltype(&EmuDenGC_GraphicsStatus) graphicsStatus = nullptr;
    decltype(&EmuDenGC_Button) button = nullptr;
    decltype(&EmuDenGC_Stick) stick = nullptr;
    decltype(&EmuDenGC_CStick) cstick = nullptr;
    decltype(&EmuDenGC_Triggers) triggers = nullptr;
    decltype(&EmuDenGC_Pause) pause = nullptr;
    decltype(&EmuDenGC_SaveState) save = nullptr;
    decltype(&EmuDenGC_LoadState) load = nullptr;
    decltype(&EmuDenGC_CopyPreview) preview = nullptr;
    decltype(&EmuDenGC_DemoStatus) status = nullptr;
    decltype(&EmuDenGC_AudioStatus) audioStatus = nullptr;
    decltype(&EmuDenGC_Stop) stop = nullptr;
};
static GameCubeAPI gameCubeAPI;

@interface EmulatorBridge () {
@public
    std::map<std::string, std::string> _options;
    std::string _savePath, _systemPath;
    BOOL _ps1;
    std::atomic_bool _gameCube;
    std::atomic_bool _nativeReady;
    CAMetalLayer* _nativeLayer;
    retro_pixel_format _pixelFormat;
    InputLatch _input;
    MotionInput _motion;
    std::atomic_int _analogX, _analogY, _rightAnalogX, _rightAnalogY;
    std::atomic_bool _ps1Analog;
#if TARGET_OS_SIMULATOR
    std::atomic_int _qaPS1Axes[4];
    std::atomic_uint _qaPS1Seen, _qaPS1Excursions;
#endif
    std::atomic_bool _paused, _framePending, _nativeFramePending;
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
    AVAudioUnitVarispeed *_speedAudio;
    CFTimeInterval _statsStart;
    std::atomic_uint _frameCount;
    std::atomic_uint64_t _sourceFrames, _uiUpdates, _copiedBytes;
    std::atomic_uint64_t _nativeFrames;
    std::atomic_uint _presentationRate;
    FrameDeliveryGate _imageDelivery, _nativeDelivery;
    CGColorSpaceRef _frameColorSpace;
    std::atomic_uint _audioOutputPeak;
    double _runSeconds, _readbackSeconds, _worstFrame;
    unsigned _benchmarkFrames, _slowFrames;
    NSInteger _resolution;
    NSInteger _ps1Resolution;
    BOOL _ps1Dithering, _ps1TextureFix;
    NSInteger _gcResolution, _gcFiltering, _gcAnisotropy;
    double _playbackSpeed;
    BOOL _asyncShaders, _prepareShaders, _optionsChanged;
    std::string _sampling;
    double _sampleSeconds, _sampleWorst, _nominalFPS;
    unsigned _sampleFrames;
}
- (void)receiveMessage:(NSString *)message;
- (void)receiveFrame:(const void *)data width:(unsigned)width height:(unsigned)height pitch:(size_t)pitch BGRA:(BOOL)bgra;
- (void)startAudio:(double)rate;
- (void)resetStatistics;
- (void)startGameCube:(NSString*)path directory:(NSString*)directory completion:(void (^)(NSString*))completion;
- (void)captureNativePreview;
- (void)publishNativeDiagnostics:(NSInteger)event;
@end

static void NativePresented(void* context, uint64_t, unsigned, unsigned) {
    EmulatorBridge* bridge = (__bridge EmulatorBridge*)context;
    bridge->_frameCount++; bridge->_sourceFrames++; bridge->_nativeFrames++;
    if (!bridge->_nativeDelivery.accept((uint64_t)(CACurrentMediaTime() * 1e9), 10)) return;
    if (bridge->_nativeFramePending.exchange(true)) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (bridge.nativeFrameHandler) { bridge->_uiUpdates++; bridge.nativeFrameHandler(bridge->_nativeFrames.load()); }
        bridge->_nativeFramePending = false;
    });
}

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
static bool SensorState(unsigned port, retro_sensor_action action, unsigned) {
    return active && !active->_ps1 && !active->_gameCube && active->_motion.state(port, action);
}
static float SensorInput(unsigned port, unsigned id) {
    return active && !active->_ps1 && !active->_gameCube ? active->_motion.read(port, id) : 0;
}
static bool Environment(unsigned command, void *data) {
    if (!active) return false;
    if (active->_gpu && active->_gpu->environment(command, data)) return true;
    switch (command) {
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
            *(const char **)data = active->_systemPath.c_str(); return true;
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
        case RETRO_ENVIRONMENT_GET_SENSOR_INTERFACE: {
            if (!data || active->_ps1 || active->_gameCube) return false;
            auto* sensors = (retro_sensor_interface*)data;
            sensors->set_sensor_state = SensorState; sensors->get_sensor_input = SensorInput; return true;
        }
        case RETRO_ENVIRONMENT_GET_JIT_CAPABLE: *(bool *)data = false; return true;
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
            auto format = *(retro_pixel_format *)data;
            if (format != RETRO_PIXEL_FORMAT_XRGB8888 && (!active->_ps1 || format != RETRO_PIXEL_FORMAT_RGB565)) return false;
            active->_pixelFormat = format; return true;
        }
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
    } else if (active && data && active->_pixelFormat == RETRO_PIXEL_FORMAT_RGB565 && w && h && w <= 4096 && h <= 4096 && pitch >= w * 2) {
        std::vector<uint32_t> pixels((size_t)w * h);
        for (unsigned y = 0; y < h; ++y) {
            const auto row = (const uint16_t *)((const uint8_t *)data + y * pitch);
            for (unsigned x = 0; x < w; ++x) {
                uint32_t p = row[x], r = (p >> 11) & 31, g = (p >> 5) & 63, b = p & 31;
                pixels[y * w + x] = ((r * 255 / 31) << 16) | ((g * 255 / 63) << 8) | (b * 255 / 31);
            }
        }
        [active receiveFrame:pixels.data() width:w height:h pitch:w * 4 BGRA:YES];
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
static void NativeAudio(void* context, const int16_t* stereo, unsigned frames) {
    if (active == (__bridge EmulatorBridge*)context) Audio(stereo, frames);
}
static void PollInput() { if (active) active->_input.poll(); }
static int16_t Input(unsigned port, unsigned device, unsigned index, unsigned id) {
    if (!active || port != 0) return 0;
    device &= RETRO_DEVICE_MASK;
    if (device == RETRO_DEVICE_JOYPAD) {
        unsigned bits = active->_input.buttons();
        if (id == RETRO_DEVICE_ID_JOYPAD_MASK) return (int16_t)bits;
        return id < 16 ? ((bits >> id) & 1) : 0;
    }
    if (device == RETRO_DEVICE_ANALOG && index <= RETRO_DEVICE_INDEX_ANALOG_RIGHT && id <= RETRO_DEVICE_ID_ANALOG_Y) {
        int16_t value = index == RETRO_DEVICE_INDEX_ANALOG_LEFT ? (id == RETRO_DEVICE_ID_ANALOG_X ? active->_analogX.load() : active->_analogY.load()) : (id == RETRO_DEVICE_ID_ANALOG_X ? active->_rightAnalogX.load() : active->_rightAnalogY.load());
#if TARGET_OS_SIMULATOR
        if (active->_ps1) { unsigned slot = index * 2 + id; active->_qaPS1Axes[slot] = value; active->_qaPS1Seen.fetch_or(1u << slot); if (std::abs((int)value) > 16000) active->_qaPS1Excursions.fetch_or(1u << slot); }
#endif
        return value;
    }
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
        _analogX = 0; _analogY = 0; _rightAnalogX = 0; _rightAnalogY = 0; _ps1Analog = false;
#if TARGET_OS_SIMULATOR
        _qaPS1Seen = 0; _qaPS1Excursions = 0; for (auto& axis : _qaPS1Axes) axis = 0;
#endif
        _paused = false; _framePending = false; _nativeFramePending = false; _nativeReady = false; _fatal = false;
        _audioRead = _audioWrite = 0;
        _audioOutputPeak = 0;
        _resolution = 1; _asyncShaders = YES; _prepareShaders = NO; _sampling = "GameControlled";
        _ps1Resolution = 1; _playbackSpeed = 1;
        _ps1Dithering = YES; _ps1TextureFix = YES;
        _gcResolution = 1; _gcFiltering = 0; _gcAnisotropy = 0;
        _optionsChanged = NO; _nominalFPS = 60; _frameCount = 0; _sourceFrames = 0; _uiUpdates = 0; _copiedBytes = 0;
        _nativeFrames = 0; _presentationRate = 0; _frameColorSpace = CGColorSpaceCreateDeviceRGB();
        _gameCube = false;
    }
    return self;
}
- (void)dealloc { if (_frameColorSpace) CGColorSpaceRelease(_frameColorSpace); }
- (void)setPresentationRate:(NSUInteger)rate {
    const unsigned value = rate == 30 ? 30 : 0;
    if (_presentationRate.exchange(value) != value) _imageDelivery.reset();
}
- (void)configureResolution:(NSInteger)resolution asyncShaders:(BOOL)asyncShaders textureSampling:(NSString *)sampling prepareShaders:(BOOL)prepare {
    const NSInteger factor = std::clamp<NSInteger>(resolution, 1, 3);
    NSString *mode = [@[@"GameControlled", @"NearestNeighbor", @"Linear"] containsObject:sampling] ? sampling : @"GameControlled";
    dispatch_async(_queue, ^{
        const bool changed = self->_resolution != factor || self->_asyncShaders != asyncShaders || self->_sampling != mode.UTF8String;
        if (changed && self->_loaded && !self->_fatal && !self->_ps1 && !self->_gameCube) {
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
- (void)setMotionHardwareAvailable:(BOOL)available { _motion.available(available, available); }
#if TARGET_OS_SIMULATOR
- (NSUInteger)motionTestStatus { return (_motion.requested() ? 1 : 0) | (_motion.active() ? 2 : 0); }
#endif
- (void)setMotionEnabled:(BOOL)enabled { _motion.enable(enabled); }
- (void)setMotionAccelerationX:(float)x y:(float)y z:(float)z rotationX:(float)rx rotationY:(float)ry rotationZ:(float)rz {
    _motion.sample({x, y, z, rx, ry, rz});
}
- (void)configurePlayStationResolution:(NSInteger)resolution dithering:(BOOL)dithering textureFix:(BOOL)textureFix {
    const NSInteger factor = resolution == 2 ? 2 : 1;
    dispatch_async(_queue, ^{
        if (self->_ps1Resolution == factor && self->_ps1Dithering == dithering && self->_ps1TextureFix == textureFix) return;
        self->_ps1Resolution = factor;
        self->_ps1Dithering = dithering; self->_ps1TextureFix = textureFix;
        if (self->_ps1 && self->_loaded) {
            self->_options["pcsx_rearmed_neon_enhancement_enable"] = factor == 2 ? "enabled" : "disabled";
            self->_options["pcsx_rearmed_dithering"] = dithering ? "enabled" : "disabled";
            self->_options["pcsx_rearmed_neon_enhancement_tex_adj_v2"] = textureFix ? "enabled" : "disabled";
            self->_optionsChanged = YES;
            CoreLog(RETRO_LOG_INFO, "PS1 GRAPHICS: internal resolution=%ldx\n", (long)factor);
        }
    });
}
- (void)configureGameCubeResolution:(NSInteger)resolution filtering:(NSInteger)filtering anisotropy:(NSInteger)anisotropy {
    dispatch_async(_queue, ^{
        self->_gcResolution = std::clamp<NSInteger>(resolution, 1, 4);
        self->_gcFiltering = filtering >= 0 && filtering <= 2 ? filtering : 0;
        self->_gcAnisotropy = [@[@0,@1,@2,@4,@8,@16] containsObject:@(anisotropy)] ? anisotropy : 0;
        if (self->_gameCube && self->_loaded)
            gameCubeAPI.configureGraphics((unsigned)self->_gcResolution, (unsigned)self->_gcFiltering, (unsigned)self->_gcAnisotropy);
    });
}
- (void)setPlaybackSpeed:(double)speed {
    const double value = speed == 1.5 || speed == 2.0 ? speed : 1.0;
    dispatch_async(_queue, ^{
        if (!self->_ps1 || self->_playbackSpeed == value) return;
        self->_playbackSpeed = value;
        CoreLog(RETRO_LOG_INFO, "PS1 PLAYBACK: requested speed=%.1fx\n", value);
        self->_speedAudio.rate = value;
        { std::lock_guard lock(self->_audioMutex); self->_audioRead = self->_audioWrite = 0; }
        if (self->_timer) dispatch_source_set_timer(self->_timer, dispatch_time(DISPATCH_TIME_NOW, 0),
            (uint64_t)(NSEC_PER_SEC / (self->_nominalFPS * value)), NSEC_PER_MSEC);
        [self resetStatistics];
    });
}
- (void)startROM:(NSString *)path saveDirectory:(NSString *)directory systemDirectory:(NSString *)system core:(NSString *)coreName completion:(void (^)(NSString *))completion {
    _gameCube = [coreName isEqualToString:@"gamecube"];
    if (_gameCube) [self nativeLayer];
    dispatch_async(_queue, ^{
        @autoreleasepool {
            if (active) { dispatch_async(dispatch_get_main_queue(), ^{ completion(@"Another emulation session is still closing. Try again in a moment."); }); return; }
            if (self->_gameCube) { [self startGameCube:path directory:directory completion:completion]; return; }
            NSString *error = nil;
            self->_ps1 = [coreName isEqualToString:@"ps1"];
            const std::string name = self->_ps1 ? "PCSXReARMed" : "Azahar";
            api = coreAPIs[name];
            if (!api.handle) {
                NSString *core = [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%s.framework/%s", name.c_str(), name.c_str()]];
                api.handle = dlopen(core.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
                if (!api.handle) error = [NSString stringWithFormat:@"Could not load %s: %s", name.c_str(), dlerror()];
#define LOAD(name) if (!error) { api.name = (decltype(api.name))dlsym(api.handle, #name); if (!api.name) error = @"The embedded core is missing " #name; }
                LOAD(retro_init) LOAD(retro_deinit) LOAD(retro_api_version)
                LOAD(retro_set_environment) LOAD(retro_set_video_refresh)
                LOAD(retro_set_audio_sample) LOAD(retro_set_audio_sample_batch)
                LOAD(retro_set_input_poll) LOAD(retro_set_input_state)
                LOAD(retro_set_controller_port_device)
                LOAD(retro_load_game) LOAD(retro_get_system_av_info) LOAD(retro_run) LOAD(retro_unload_game)
                LOAD(retro_serialize_size) LOAD(retro_serialize) LOAD(retro_unserialize)
#undef LOAD
                if (!error && api.retro_api_version() != RETRO_API_VERSION) error = @"The embedded core uses an unsupported API version.";
                if (error && api.handle) { dlclose(api.handle); api = CoreAPI{}; }
                if (!error) coreAPIs[name] = api;
            }
            if (!error) {
                active = self;
                self->_savePath = directory.UTF8String;
                self->_systemPath = system.UTF8String;
                self->_pixelFormat = RETRO_PIXEL_FORMAT_XRGB8888;
                [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
                [NSFileManager.defaultManager createDirectoryAtPath:system withIntermediateDirectories:YES attributes:nil error:nil];
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
                if (!self->_ps1) self->_gpu = std::make_unique<VulkanVideo>(metal.fileSystemRepresentation, std::move(handler));
                self->_options = {{"citra_graphics_api","Vulkan"}, {"citra_use_cpu_jit","disabled"}, {"citra_use_fastinterp","enabled"},
                    {"citra_use_shader_jit","disabled"}, {"citra_use_hw_shader","enabled"},
                    {"citra_resolution_factor","1"}, {"citra_layout_option","default"},
                    {"citra_use_libretro_save_path","LibRetro Default"}, {"citra_enable_motion","enabled"},
                    {"citra_enable_mouse_touchscreen","disabled"}, {"citra_enable_touch_touchscreen","enabled"}};
                self->_options["citra_resolution_factor"] = std::to_string(self->_resolution);
                self->_options["citra_async_shader_compilation"] = self->_asyncShaders ? "enabled" : "disabled";
                self->_options["citra_texture_sampling"] = self->_sampling;
                self->_options["emuden_prepare_cached_shaders"] = self->_prepareShaders ? "enabled" : "disabled";
                self->_options["citra_use_disk_shader_cache"] = "enabled";
                if (self->_ps1) self->_options = {{"pcsx_rearmed_drc", "disabled"}, {"pcsx_rearmed_bios", "auto"},
                    {"pcsx_rearmed_memcard1", "shared"}, {"pcsx_rearmed_memcard2", "shared"},
                    {"pcsx_rearmed_rgb32_output", "enabled"}, {"pcsx_rearmed_frameskip_type", "disabled"},
                    {"pcsx_rearmed_neon_enhancement_enable", self->_ps1Resolution == 2 ? "enabled" : "disabled"},
                    {"pcsx_rearmed_neon_enhancement_no_main", "disabled"},
                    {"pcsx_rearmed_neon_enhancement_tex_adj_v2", self->_ps1TextureFix ? "enabled" : "disabled"},
                    {"pcsx_rearmed_dithering", self->_ps1Dithering ? "enabled" : "disabled"},
                    {"pcsx_rearmed_region", "auto"}};
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
                    NSString *current = [directory stringByAppendingPathComponent:self->_ps1 ? @"ps1-session.log" : @"azahar-session.log"];
                    NSString *previous = [directory stringByAppendingPathComponent:self->_ps1 ? @"ps1-session-previous.log" : @"azahar-session-previous.log"];
                    rename(current.fileSystemRepresentation, previous.fileSystemRepresentation);
                    logFile = fopen(current.fileSystemRepresentation, "w");
                }
                try {
                    api.retro_set_environment(Environment); api.retro_set_video_refresh(Video);
                    api.retro_set_audio_sample(AudioSample); api.retro_set_audio_sample_batch(Audio);
                    api.retro_set_input_poll(PollInput); api.retro_set_input_state(Input);
                    if (self->_ps1) {
                        api.padToggleAnalog = (decltype(api.padToggleAnalog))dlsym(api.handle, "padToggleAnalog");
                        if (!api.padToggleAnalog) throw std::runtime_error("The PlayStation core is missing its analog controller interface");
                    }
                    api.retro_init(); self->_initialized = YES;
                    if (self->_ps1) CoreLog(RETRO_LOG_INFO, "EmuDen PS1: interpreter, NEON software GPU, JIT compiled out; separate per-game memory cards\n");
                    else { CoreLog(RETRO_LOG_INFO, "EmuDen shaders: async=%s, disk_cache=enabled; CPU=FastInterp; CPU/shader JIT disabled\n",
                            self->_options["citra_async_shader_compilation"].c_str());
                    CoreLog(RETRO_LOG_INFO, "EmuDen graphics: resolution=%sx native, GPU readback=%s\n", self->_options["citra_resolution_factor"].c_str(), pipeline ? "asynchronous, shared-image completion guard" : "synchronous");
                    CoreLog(RETRO_LOG_INFO, "PERF note: GPU readback reports frontend CPU submission/blocking time, not GPU execution time.\n");
                    }
                    struct utsname machine{}; uname(&machine);
#if TARGET_OS_SIMULATOR
                    CoreLog(RETRO_LOG_INFO, "Benchmark environment: iOS Simulator model=%s host=%s; timings use the Mac CPU/GPU\n",
                            NSProcessInfo.processInfo.environment[@"SIMULATOR_MODEL_IDENTIFIER"].UTF8String ?: "unknown", machine.machine);
#else
                    CoreLog(RETRO_LOG_INFO, "Benchmark environment: physical iOS device model=%s\n", machine.machine);
#endif
                    retro_game_info info{}; info.path = path.fileSystemRepresentation;
                    self->_loaded = api.retro_load_game(&info);
                    if (!self->_loaded) error = self->_ps1 ? @"PlayStation could not boot this game. Check the disc format and all CUE tracks. Some games require a BIOS dumped from your console." : @"Azahar could not boot this game. Check that it is decrypted and review the session log in Files → EmuDen → Saves.";
                    else {
                        if (self->_ps1) [self applyPlayStationController];
                        if (self->_gpu) {
                            if (!self->_gpu->requested()) throw std::runtime_error("The core did not enable the GPU renderer");
                            self->_gpu->initialize();
                            self->_gpu->finishFrames();
                            CoreLog(RETRO_LOG_INFO, "Frontend GPU: %s (MoltenVK)\n", self->_gpu->deviceName().c_str());
                        }
                        if (self->_fatal) throw std::runtime_error(self->_lastError.UTF8String ?: "The core could not initialize the game");
                        retro_system_av_info av{}; api.retro_get_system_av_info(&av);
                        [self startAudio:av.timing.sample_rate];
                        self->_nominalFPS = std::max(1.0, av.timing.fps);
                        [self resetStatistics];
                        self->_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self->_queue);
                        uint64_t interval = (uint64_t)(NSEC_PER_SEC / (self->_nominalFPS * (self->_ps1 ? self->_playbackSpeed : 1)));
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
                                            @"sourceFramesTotal": @(strongSelf->_sourceFrames.load()), @"uiUpdatesTotal": @(strongSelf->_uiUpdates.load()), @"copiedBytesTotal": @(strongSelf->_copiedBytes.load()), @"resolution": @(strongSelf->_ps1 ? strongSelf->_ps1Resolution : strongSelf->_resolution)};
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
                } catch (const std::exception &e) { error = [NSString stringWithFormat:@"%@ initialization failed: %s", self->_ps1 ? @"PlayStation" : @"Azahar", e.what()]; }
                catch (...) { error = self->_ps1 ? @"PlayStation initialization failed." : @"Azahar initialization failed."; }
            }
            dispatch_async(dispatch_get_main_queue(), ^{ completion(error); });
        }
    });
}
- (CAMetalLayer*)nativeLayer {
    if (!_nativeLayer) { _nativeLayer = [CAMetalLayer layer]; _nativeLayer.opaque = YES; }
    return _nativeLayer;
}
- (void)nativeSurfaceChanged {
    if (_gameCube && _nativeReady) gameCubeAPI.resize();
}
- (void)startGameCube:(NSString*)path directory:(NSString*)directory completion:(void (^)(NSString*))completion {
    NSString* error = nil;
    if (!gameCubeAPI.handle) {
        NSString* core = [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"EmuDenGameCube.framework/EmuDenGameCube"];
        gameCubeAPI.handle = dlopen(core.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
        if (!gameCubeAPI.handle) error = @"The experimental GameCube core is not included in this build.";
#define GC_LOAD(field, symbol) if (!error) { gameCubeAPI.field = (decltype(gameCubeAPI.field))dlsym(gameCubeAPI.handle, #symbol); if (!gameCubeAPI.field) error = @"The experimental GameCube core is incomplete."; }
        GC_LOAD(start, EmuDenGC_Start) GC_LOAD(pump, EmuDenGC_Pump) GC_LOAD(resize, EmuDenGC_Resize)
        GC_LOAD(configureGraphics, EmuDenGC_ConfigureGraphics) GC_LOAD(graphicsStatus, EmuDenGC_GraphicsStatus)
        GC_LOAD(button, EmuDenGC_Button) GC_LOAD(stick, EmuDenGC_Stick) GC_LOAD(pause, EmuDenGC_Pause)
        GC_LOAD(cstick, EmuDenGC_CStick) GC_LOAD(triggers, EmuDenGC_Triggers)
        GC_LOAD(save, EmuDenGC_SaveState) GC_LOAD(load, EmuDenGC_LoadState)
        GC_LOAD(preview, EmuDenGC_CopyPreview) GC_LOAD(stop, EmuDenGC_Stop)
        GC_LOAD(status, EmuDenGC_DemoStatus)
        GC_LOAD(audioStatus, EmuDenGC_AudioStatus)
#undef GC_LOAD
        if (error && gameCubeAPI.handle) { dlclose(gameCubeAPI.handle); gameCubeAPI = {}; }
    }
    if (!error) {
        NSFileManager* files = NSFileManager.defaultManager;
        NSString* settings = [directory stringByAppendingPathComponent:@"GameSettings"];
        NSString* profile = [settings stringByAppendingPathComponent:@"GZD.ini"];
        NSError* preparationError = nil;
        if (![files createDirectoryAtPath:settings withIntermediateDirectories:YES attributes:nil error:&preparationError]) {
            error = @"GameCube could not prepare its compatibility settings.";
        } else if (![files fileExistsAtPath:profile]) {
            // Dolphin loads this title-specific profile before boot; preserve existing user overrides.
            NSURL* bundled = [NSBundle.mainBundle URLForResource:@"GZD" withExtension:@"ini" subdirectory:@"GameCubeCompatibility"];
            if (!bundled || ![files copyItemAtURL:bundled toURL:[NSURL fileURLWithPath:profile] error:&preparationError])
                error = @"GameCube could not install its compatibility settings.";
        }
    }
    if (!error) {
        _savePath = directory.UTF8String;
        active = self;
        EmuDenGCCallbacks callbacks = {(__bridge void*)self, NativePresented, NativeAudio};
        gameCubeAPI.configureGraphics((unsigned)_gcResolution, (unsigned)_gcFiltering, (unsigned)_gcAnisotropy);
        if (!gameCubeAPI.start(path.fileSystemRepresentation, directory.fileSystemRepresentation, (__bridge void*)_nativeLayer, callbacks)) {
            error = @"GameCube could not start this game."; active = nil;
        } else {
            [self startAudio:48000];
            _initialized = _loaded = YES;
            _nativeReady = true;
            [self resetStatistics];
            _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue);
            dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, 10 * NSEC_PER_MSEC, NSEC_PER_MSEC);
            __weak EmulatorBridge* weakSelf = self;
            dispatch_source_set_event_handler(_timer, ^{
                EmulatorBridge* s = weakSelf;
                if (!s || s->_fatal) return;
                @autoreleasepool {
                    if (!gameCubeAPI.pump()) { s->_fatal = true; [s receiveMessage:@"GameCube stopped unexpectedly. Reopen the game to continue."]; return; }
                    const double elapsed = CACurrentMediaTime() - s->_statsStart;
                    if (elapsed >= 1 && !s->_paused) {
                        [s publishNativeDiagnostics:0];
                        const double fps = s->_frameCount.exchange(0) / elapsed;
                        s->_statsStart = CACurrentMediaTime();
                        NSDictionary* sample = @{@"fps":@(fps), @"coreFPS":@(fps), @"targetFPS":@60,
                            @"meanMS":@(fps > 0 ? 1000/fps : 0), @"worstMS":@0,
                            @"thermal":@((NSInteger)NSProcessInfo.processInfo.thermalState), @"sourceFramesTotal":@(s->_sourceFrames.load()), @"uiUpdatesTotal":@(s->_uiUpdates.load()), @"copiedBytesTotal":@(s->_copiedBytes.load()), @"resolution":@(s->_gcResolution)};
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (s.statisticsHandler) s.statisticsHandler(fps);
                            if (s.performanceHandler) s.performanceHandler(sample);
                        });
                    }
                }
            });
            dispatch_resume(_timer);
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{ completion(error); });
}
- (void)captureNativePreview {
    unsigned width = 0, height = 0;
    if (!gameCubeAPI.preview(nullptr, 0, &width, &height) || !width || !height || width > 4096 || height > 4096) return;
    NSMutableData* bytes = [NSMutableData dataWithLength:(size_t)width * height * 4];
    if (bytes && gameCubeAPI.preview((uint8_t*)bytes.mutableBytes, bytes.length, &width, &height))
        [self receiveFrame:bytes.bytes width:width height:height pitch:width*4 BGRA:NO];
}
- (void)publishNativeDiagnostics:(NSInteger)event {
#if TARGET_OS_SIMULATOR
    if (!_loaded || ![NSProcessInfo.processInfo.arguments containsObject:@"--gamecube-qa-status"]) return;
    const auto value = gameCubeAPI.status();
    const auto sound = gameCubeAPI.audioStatus();
    const auto graphics = gameCubeAPI.graphicsStatus();
    NSDictionary* data = @{@"marker":@(value.marker), @"counter":@(value.counter), @"pad":@(value.pad), @"padLow":@(value.pad_low), @"pixel":@(value.first_pixel), @"event":@(event), @"audioFrames":@(sound.frames), @"audioPeak":@(sound.peak), @"audioOutputPeak":@(self->_audioOutputPeak.load()),
        @"resolution":@(graphics.resolution), @"filtering":@(graphics.filtering), @"anisotropy":@(graphics.anisotropy), @"efbWidth":@(graphics.efb_width), @"efbHeight":@(graphics.efb_height)};
    dispatch_async(dispatch_get_main_queue(), ^{ if (self.nativeDiagnosticHandler) self.nativeDiagnosticHandler(data); });
#endif
}
- (void)receiveMessage:(NSString *)message {
    if (_ps1 && [message hasPrefix:@"No PlayStation BIOS file found"]) {
        CoreLog(RETRO_LOG_INFO, "%s; using HLE. BIOS import is available in Player settings.\n", message.UTF8String); return;
    }
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
    _frameCount++; _sourceFrames++;
    if (!_imageDelivery.accept((uint64_t)(CACurrentMediaTime() * 1e9), _presentationRate.load())) return;
    if (_framePending.exchange(true)) return;
    CFDataRef copy = CFDataCreate(kCFAllocatorDefault, (const UInt8 *)data, pitch * h);
    if (!copy) { _framePending = false; return; }
    _copiedBytes += pitch * h;
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(copy);
    if (!provider) { CFRelease(copy); _framePending = false; return; }
    CGBitmapInfo format = bgra ? kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst
                               : kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipLast;
    CGImageRef cg = _frameColorSpace ? CGImageCreate(w, h, 8, 32, pitch, _frameColorSpace, format, provider, nullptr, false, kCGRenderingIntentDefault) : nullptr;
    UIImage *image = cg ? [UIImage imageWithCGImage:cg] : nil;
    if (cg) CGImageRelease(cg); CGDataProviderRelease(provider); CFRelease(copy);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (image && self.frameHandler) { self->_uiUpdates++; self.frameHandler(image); }
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
        unsigned peak = 0;
        for (UInt32 i = 0; i < frames; i++) {
            if (s->_audioRead == s->_audioWrite) break;
            for (UInt32 channel = 0; channel < 2; channel++) {
                float sample = s->_audioRing[s->_audioRead];
                peak = std::max(peak, (unsigned)((sample < 0 ? -sample : sample) * 32768));
                s->_audioRead = (s->_audioRead + 1) % s->_audioRing.size();
                if (channel < list->mNumberBuffers) ((float *)list->mBuffers[channel].mData)[i] = sample;
            }
        }
        s->_audioOutputPeak.store(std::max(s->_audioOutputPeak.load(), peak));
        return noErr;
    }];
    [_audioEngine attachNode:_audioSource];
    if (_ps1) {
        _speedAudio = [AVAudioUnitVarispeed new]; _speedAudio.rate = _playbackSpeed;
        [_audioEngine attachNode:_speedAudio];
        [_audioEngine connect:_audioSource to:_speedAudio format:format];
        [_audioEngine connect:_speedAudio to:_audioEngine.mainMixerNode format:format];
    } else [_audioEngine connect:_audioSource to:_audioEngine.mainMixerNode format:format];
    if (![_audioEngine startAndReturnError:&error]) [self receiveMessage:[@"Audio unavailable: " stringByAppendingString:error.localizedDescription]];
}
- (void)setButton:(unsigned)button pressed:(BOOL)pressed {
    if (_gameCube) { if (_nativeReady) gameCubeAPI.button(button, pressed); return; }
    _input.setButton(button, pressed);
}
- (void)setAnalogX:(float)x y:(float)y {
    if (_gameCube) { if (_nativeReady) gameCubeAPI.stick(x, -y); return; }
    _analogX = (int)(std::clamp(std::isfinite(x) ? x : 0, -1.0f, 1.0f) * 32767); _analogY = (int)(std::clamp(std::isfinite(y) ? y : 0, -1.0f, 1.0f) * 32767);
}
- (void)setRightAnalogX:(float)x y:(float)y {
    _rightAnalogX = (int)(std::clamp(std::isfinite(x) ? x : 0, -1.0f, 1.0f) * 32767);
    _rightAnalogY = (int)(std::clamp(std::isfinite(y) ? y : 0, -1.0f, 1.0f) * 32767);
}
- (void)applyPlayStationController {
    // Switching through the digital pad resets the core's saved analog-mode latch.
    api.retro_set_controller_port_device(0, RETRO_DEVICE_JOYPAD);
    if (_ps1Analog) {
        api.retro_set_controller_port_device(0, RETRO_DEVICE_SUBCLASS(RETRO_DEVICE_ANALOG, 1));
        api.padToggleAnalog(0);
    }
    CoreLog(RETRO_LOG_INFO, "EmuDen PS1 controller: %s\n", _ps1Analog ? "dual analog" : "digital");
}
- (void)setPlayStationAnalogEnabled:(BOOL)enabled {
    const bool changed = _ps1Analog.exchange(enabled) != (bool)enabled;
    if (changed) dispatch_async(_queue, ^{ if (self->_ps1 && self->_loaded) [self applyPlayStationController]; });
}
#if TARGET_OS_SIMULATOR
- (NSString *)playStationInputStatus {
    return [NSString stringWithFormat:@"PS1 axes L(%d,%d) R(%d,%d) seen=%u excursion=%u mode=%d", _qaPS1Axes[0].load(), _qaPS1Axes[1].load(), _qaPS1Axes[2].load(), _qaPS1Axes[3].load(), _qaPS1Seen.load(), _qaPS1Excursions.load(), (int)_ps1Analog.load()];
}
#endif
- (void)setGameCubeCStickX:(float)x y:(float)y {
    if (_gameCube && _nativeReady) gameCubeAPI.cstick(x, -y);
}
- (void)setGameCubeTriggerLeft:(float)left right:(float)right {
    if (_gameCube && _nativeReady) gameCubeAPI.triggers(left, right);
}
- (void)setTouchX:(float)x y:(float)y pressed:(BOOL)pressed {
    _input.setTouch((int)(std::clamp(x, 0.0f, 1.0f) * 65534 - 32767),
                    (int)(std::clamp(y, 0.0f, 1.0f) * 65534 - 32767), pressed);
}
- (void)setPaused:(BOOL)paused {
    if (paused) _motion.enable(false);
    if (_gameCube) {
        _paused = paused;
        dispatch_async(_queue, ^{
            if (self->_loaded) gameCubeAPI.pause(paused);
            if (paused && self->_loaded) { for (unsigned n=0;n<16;++n) gameCubeAPI.button(n, false); gameCubeAPI.stick(0,0); gameCubeAPI.cstick(0,0); gameCubeAPI.triggers(0,0); }
            [self resetStatistics];
        });
        return;
    }
    if (paused) _paused = true;
    else dispatch_async(_queue, ^{ [self resetStatistics]; self->_paused = false; });
    if (paused) { _input.clear(); _analogX = 0; _analogY = 0; _rightAnalogX = 0; _rightAnalogY = 0; }
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
            if (self->_gameCube) {
                NSString* file = [@(self->_savePath.c_str()) stringByAppendingPathComponent:[NSString stringWithFormat:@".capture-%@.state", NSUUID.UUID.UUIDString]];
#if TARGET_OS_SIMULATOR
                // Simulator diagnostics bracket the atomic snapshot. The core may keep
                // running while its state file is compressed, so the post-write counter
                // alone is not the counter serialized into that snapshot.
                [self publishNativeDiagnostics:3];
#endif
                if (self->_loaded && !self->_fatal && gameCubeAPI.save(file.fileSystemRepresentation)) {
                    NSDictionary* info = [NSFileManager.defaultManager attributesOfItemAtPath:file error:nil];
                    if ([info fileSize] >= 256 && [info fileSize] <= 256*1024*1024) data = [NSData dataWithContentsOfFile:file];
                    [self captureNativePreview];
                    [self publishNativeDiagnostics:1];
                }
                [NSFileManager.defaultManager removeItemAtPath:file error:nil];
                if (!data) error = @"GameCube could not capture this point. Previous saves are unchanged.";
                dispatch_async(dispatch_get_main_queue(), ^{ completion(data, error); }); return;
            }
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
        if (self->_gameCube) {
            NSString* file = [@(self->_savePath.c_str()) stringByAppendingPathComponent:[NSString stringWithFormat:@".restore-%@.state", NSUUID.UUID.UUIDString]];
            if (!self->_loaded || self->_fatal || data.length < 256 || data.length > 256*1024*1024 ||
                ![data writeToFile:file options:NSDataWritingAtomic error:nil] || !gameCubeAPI.load(file.fileSystemRepresentation))
                error = @"GameCube could not load this point. Your files are unchanged.";
            [NSFileManager.defaultManager removeItemAtPath:file error:nil];
            { std::lock_guard lock(self->_audioMutex); self->_audioRead = self->_audioWrite = 0; }
            for (unsigned n=0;n<16;++n) if (gameCubeAPI.button) gameCubeAPI.button(n, false);
            if (gameCubeAPI.stick) gameCubeAPI.stick(0,0);
            if (gameCubeAPI.cstick) gameCubeAPI.cstick(0,0);
            if (gameCubeAPI.triggers) gameCubeAPI.triggers(0,0);
            [self resetStatistics];
            if (!error) { [self captureNativePreview]; [self publishNativeDiagnostics:2]; }
            dispatch_async(dispatch_get_main_queue(), ^{ completion(error); }); return;
        }
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
        self->_input.clear(); self->_analogX = 0; self->_analogY = 0; self->_rightAnalogX = 0; self->_rightAnalogY = 0;
        { std::lock_guard<std::mutex> lock(self->_audioMutex); self->_audioRead = self->_audioWrite = 0; }
        [self resetStatistics];
        CoreLog(error ? RETRO_LOG_ERROR : RETRO_LOG_INFO, "STATE: restore %s\n", error ? "failed" : "complete");
        dispatch_async(dispatch_get_main_queue(), ^{ completion(error); });
    });
}
- (void)stopWithCompletion:(void (^)(void))completion {
    _motion.enable(false);
    _nativeReady = false;
    _paused = true;
    if (_timer) { dispatch_source_cancel(_timer); _timer = nil; }
    dispatch_async(_queue, ^{
        if (self->_timer) { dispatch_source_cancel(self->_timer); self->_timer = nil; }
        if (self->_gameCube) {
            if (self->_initialized) gameCubeAPI.stop();
            [self->_audioEngine stop]; self->_audioEngine = nil; self->_audioSource = nil;
            { std::lock_guard lock(self->_audioMutex); self->_audioRead = self->_audioWrite = 0; }
            self->_loaded = self->_initialized = NO;
            if (active == self) active = nil;
            dispatch_async(dispatch_get_main_queue(), ^{ completion(); }); return;
        }
        [self->_audioEngine stop]; self->_audioEngine = nil; self->_audioSource = nil; self->_speedAudio = nil;
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
                NSString *current = [@(self->_savePath.c_str()) stringByAppendingPathComponent:self->_ps1 ? @"ps1-session.log" : @"azahar-session.log"];
                NSData *log = [NSData dataWithContentsOfFile:current];
                [log writeToFile:self->_logCopyPath options:NSDataWritingAtomic error:nil];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(); });
    });
}
@end
