// Exercises the same official core version in software/interpreter mode on the Mac.
// This is a core/ROM compatibility check; it does not substitute for an iOS device test.
#include "libretro.h"
#include "VulkanVideo.h"
#include <dlfcn.h>
#include <map>
#include <string>
#include <cstdio>
#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <algorithm>
#include <unistd.h>
#include <chrono>
#include <memory>
#include <stdexcept>
#include <execinfo.h>
#include <csignal>
#include <thread>
#include <atomic>
#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif
static std::map<std::string,std::string> options = {
    {"citra_graphics_api","Software"}, {"citra_use_cpu_jit","disabled"},
    {"citra_use_shader_jit","disabled"}, {"citra_use_hw_shader","disabled"},
    {"citra_resolution_factor","1"}, {"citra_layout_option","default"},
    {"citra_use_libretro_save_path","LibRetro Default"}, {"citra_enable_motion","disabled"}
};
static std::string saves, output;
static unsigned frames = 0, nonblack = 0;
static std::unique_ptr<VulkanVideo> gpu;
static bool fatal = false;
static bool gameplay = false;
static unsigned targetFrames = 0;
static bool quietFrames = false;
static void runFrame(void (*run)()) {
#ifdef __OBJC__
    @autoreleasepool { run(); }
#else
    run();
#endif
}
static void logger(enum retro_log_level, const char *format, ...) {
    va_list args; va_start(args,format); vfprintf(stderr,format,args); va_end(args);
}
static bool environment(unsigned cmd, void *data) {
    if(gpu && gpu->environment(cmd,data)) return true;
    switch(cmd) {
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY: *(const char **)data = saves.c_str(); return true;
        case RETRO_ENVIRONMENT_GET_LOG_INTERFACE: ((retro_log_callback *)data)->log=logger; return true;
        case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION: *(unsigned *)data=2; return true;
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2: {
            for(auto *o=((retro_core_options_v2 *)data)->definitions; o && o->key; ++o)
                if(!options.count(o->key)) options[o->key]=o->default_value ? o->default_value : o->values[0].value;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_VARIABLE: {
            auto *v=(retro_variable *)data; auto it=options.find(v->key);
            v->value=it==options.end() ? nullptr : it->second.c_str(); return v->value!=nullptr;
        }
        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE: *(bool *)data=false; return true;
        case RETRO_ENVIRONMENT_GET_JIT_CAPABLE: *(bool *)data=false; return true;
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: return *(retro_pixel_format *)data==RETRO_PIXEL_FORMAT_XRGB8888;
        case RETRO_ENVIRONMENT_GET_CAN_DUPE: *(bool *)data=true; return true;
        case RETRO_ENVIRONMENT_SET_MESSAGE:
            fprintf(stderr,"MESSAGE: %s\n",((retro_message *)data)->msg);
            fatal=true; return true;
        case RETRO_ENVIRONMENT_SET_GEOMETRY:
        case RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO:
        case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
        case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
        case RETRO_ENVIRONMENT_SET_MEMORY_MAPS:
        case RETRO_ENVIRONMENT_SET_SERIALIZATION_QUIRKS: return true;
        default: return false;
    }
}
static void video(const void *data,unsigned w,unsigned h,size_t pitch) {
    bool bgra = true;
    if(data==RETRO_HW_FRAME_BUFFER_VALID && gpu) {
        const auto frame=gpu->readFrame(w,h);
        data=frame.data; bgra=frame.bgra; pitch=w*4;
    }
    if(!data || data==RETRO_HW_FRAME_BUFFER_VALID) return;
    frames++;
    const uint8_t *bytes=(const uint8_t *)data;
    unsigned colored=0;
    for(unsigned y=0;y<h;y++) for(unsigned x=0;x<w;x++) {
        const auto *pixel=bytes+y*pitch+x*4;
        if(pixel[0] || pixel[1] || pixel[2]) colored++;
    }
    if(colored) nonblack++;
    if(frames%60==0 && (!quietFrames || frames%300==0)) {
        auto save=[&](const std::string& path) {
        FILE *file=fopen(path.c_str(),"wb");
        if(file) {
            fprintf(file,"P6\n%u %u\n255\n",w,h);
            for(unsigned y=0;y<h;y++) for(unsigned x=0;x<w;x++) {
                const auto *pixel=bytes+y*pitch+x*4;
                uint8_t rgb[]={pixel[bgra ? 2 : 0],pixel[1],pixel[bgra ? 0 : 2]}; fwrite(rgb,1,3,file);
            }
            fclose(file);
        }
        };
        save(output);
        if(gameplay && frames%300==0) save(output+"."+std::to_string(frames)+".ppm");
    }
}
static size_t audio(const int16_t *,size_t frames) { return frames; }
static void sample(int16_t,int16_t) {}
static void poll() {}
static int16_t input(unsigned port,unsigned device,unsigned,unsigned id) {
    if(gameplay && port==0 && (device & RETRO_DEVICE_MASK)==RETRO_DEVICE_POINTER) {
        // Select the USA flag in first-run save setup. Coordinates refer to the 400x480 core output.
        if(id==RETRO_DEVICE_ID_POINTER_X) return int16_t((139.0/400)*65534-32767);
        if(id==RETRO_DEVICE_ID_POINTER_Y) return int16_t((395.0/480)*65534-32767);
        if(id==RETRO_DEVICE_ID_POINTER_PRESSED || id==RETRO_DEVICE_ID_POINTER_COUNT)
            return frames>=720 && frames<726;
    }
    // A presses advance the title/default menu path in the Mario Golf regression run.
    if(gameplay && port==0 && (device & RETRO_DEVICE_MASK)==RETRO_DEVICE_JOYPAD && frames>=180 && frames%120<6) {
        if(id==RETRO_DEVICE_ID_JOYPAD_MASK) return int16_t(1u<<8);
        if(id==8) return 1;
    }
    return 0;
}
int smokeMain(int argc,char **argv) {
    signal(SIGSEGV, [](int) {
        void* stack[64]; const int count=backtrace(stack,64);
        backtrace_symbols_fd(stack,count,STDERR_FILENO); _exit(139);
    });
    if(argc<5 || argc>7) return 2;
    gameplay=argc==7 && std::string(argv[6])=="--gameplay";
    if(const char* value=getenv("EMUDEN_SMOKE_FRAMES")) targetFrames=std::max(120,atoi(value));
    quietFrames=getenv("EMUDEN_SMOKE_QUIET_FRAMES") != nullptr;
    alarm(gameplay ? 600 : 180);
    saves=argv[3]; output=argv[4];
    void *handle=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);
    if(!handle) { fprintf(stderr,"dlopen: %s\n",dlerror()); return 3; }
#define FN(name) auto name=(decltype(&::name))dlsym(handle,#name); if(!name) return 4;
    FN(retro_set_environment) FN(retro_set_video_refresh) FN(retro_set_audio_sample)
    FN(retro_set_audio_sample_batch) FN(retro_set_input_poll) FN(retro_set_input_state)
    FN(retro_init) FN(retro_load_game) FN(retro_run) FN(retro_unload_game) FN(retro_deinit)
    FN(retro_serialize_size) FN(retro_serialize) FN(retro_unserialize)
    retro_set_environment(environment); retro_set_video_refresh(video);
    retro_set_audio_sample(sample); retro_set_audio_sample_batch(audio);
    retro_set_input_poll(poll); retro_set_input_state(input);
    for(unsigned session=1;session<=(gameplay ? 1u : 2u);session++) {
        frames=nonblack=0; fatal=false;
        if(argc>=6) {
            gpu=std::make_unique<VulkanVideo>(argv[5]);
            options["citra_graphics_api"]="Vulkan";
            options["citra_use_hw_shader"]="enabled";
            options["citra_use_shader_jit"]="disabled";
        }
        retro_init();
        retro_game_info info{}; info.path=argv[2];
        bool loaded=retro_load_game(&info);
        if(!loaded) { fprintf(stderr,"LOAD FAILED\n"); retro_deinit(); return 5; }
        int result=0;
        try {
            if(gpu) {
                if(!gpu->requested()) throw std::runtime_error("Vulkan was not requested by the core");
#ifdef __OBJC__
                @autoreleasepool { gpu->initialize(); }
#else
                gpu->initialize();
#endif
                fprintf(stderr,"GPU: %s\n",gpu->deviceName().c_str());
            }
            auto start=std::chrono::steady_clock::now();
            const unsigned target=targetFrames ? targetFrames : (gameplay ? 3600 : 120);
            auto segment=start;
            for(unsigned i=0;i<target && !fatal;i++) {
                runFrame(retro_run);
                if((i+1)%120==0) {
                    auto now=std::chrono::steady_clock::now();
                    printf("BENCH frame=%u ms=%.3f\n",i+1,std::chrono::duration<double>(now-segment).count()*1000/120);
                    fflush(stdout); segment=now;
                }
            }
            if(getenv("EMUDEN_SMOKE_STATE")) {
                size_t size=retro_serialize_size();
                if(size<256 || size>256*1024*1024) throw std::runtime_error("Invalid captured state size");
                std::vector<uint8_t> state(size);
                if(!retro_serialize(state.data(),state.size())) throw std::runtime_error("Serialize failed");
                for(unsigned i=0;i<120;i++) runFrame(retro_run);
                if(!retro_unserialize(state.data(),state.size())) throw std::runtime_error("Unserialize failed");
                for(unsigned i=0;i<120;i++) runFrame(retro_run);
                printf("STATE ROUND TRIP PASSED: %zu bytes, continued rendering\n",size);
            }
            double seconds=std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count();
            printf("Session %u (%s): %u frames, %u non-black, %.2f seconds, %.2f FPS\n",
                   session,gpu ? "Vulkan" : "Software",frames,nonblack,seconds,frames/seconds);
            fflush(stdout);
            if(fatal || frames<target || !nonblack) result=6;
        } catch(const std::exception& error) {
            fprintf(stderr,"SMOKE FAILED: %s\n",error.what()); result=7;
        }
        retro_unload_game();
        if(gpu) gpu->destroyContext();
        retro_deinit(); gpu.reset();
        if(result) return result;
    }
    return 0;
}

int main(int argc, char** argv) {
#ifdef __OBJC__
    @autoreleasepool {
        std::atomic_bool done{false}; int result=2;
        std::thread worker([&] { @autoreleasepool { result=smokeMain(argc,argv); done=true; } });
        while (!done) CFRunLoopRunInMode(kCFRunLoopDefaultMode,0.05,false);
        worker.join(); return result;
    }
#else
    return smokeMain(argc,argv);
#endif
}
