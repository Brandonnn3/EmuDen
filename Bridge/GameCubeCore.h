#pragma once
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif
#define EMUDEN_GC_API __attribute__((visibility("default")))

// Call start/pump/state/stop on one host queue; the callback context lives until stop returns.
typedef struct {
    void* context;
    void (*presented)(void* context, uint64_t frame, unsigned width, unsigned height);
    void (*audio)(void* context, const int16_t* stereo, unsigned frames);
} EmuDenGCCallbacks;

EMUDEN_GC_API bool EmuDenGC_Start(const char* rom, const char* user_directory,
                                void* metal_layer, EmuDenGCCallbacks callbacks);
EMUDEN_GC_API bool EmuDenGC_Pump(void);
EMUDEN_GC_API void EmuDenGC_Resize(void);
EMUDEN_GC_API void EmuDenGC_ConfigureGraphics(unsigned resolution, unsigned filtering, unsigned anisotropy);
EMUDEN_GC_API void EmuDenGC_Button(unsigned libretro_button, bool pressed);
EMUDEN_GC_API void EmuDenGC_Stick(float x, float y);
EMUDEN_GC_API void EmuDenGC_CStick(float x, float y);
EMUDEN_GC_API void EmuDenGC_Triggers(float left, float right);
EMUDEN_GC_API void EmuDenGC_Pause(bool paused);
EMUDEN_GC_API bool EmuDenGC_SaveState(const char* path);
EMUDEN_GC_API bool EmuDenGC_LoadState(const char* path);
EMUDEN_GC_API bool EmuDenGC_CopyPreview(uint8_t* bytes, size_t capacity, unsigned* width, unsigned* height);
EMUDEN_GC_API void EmuDenGC_Stop(void);

// Bounded original-homebrew assertions for the isolated native test frontend.
typedef struct { uint32_t marker, counter, pad, first_pixel, pad_low; } EmuDenGCDemoStatus;
EMUDEN_GC_API EmuDenGCDemoStatus EmuDenGC_DemoStatus(void);
typedef struct { uint64_t frames; uint32_t peak; } EmuDenGCAudioStatus;
EMUDEN_GC_API EmuDenGCAudioStatus EmuDenGC_AudioStatus(void);
typedef struct { unsigned resolution, filtering; int anisotropy; unsigned efb_width, efb_height; } EmuDenGCGraphicsStatus;
EMUDEN_GC_API EmuDenGCGraphicsStatus EmuDenGC_GraphicsStatus(void);
#ifdef __cplusplus
}
#endif
