// Original PS1 homebrew integration check. Mac timing is not iPhone performance.
#include "libretro.h"
#include <dlfcn.h>
#include <cassert>
#include <cstdarg>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <map>
#include <string>
#include <vector>
#include <filesystem>
#include <fstream>
#include <iterator>

static std::map<std::string, std::string> options = {
    {"pcsx_rearmed_bios", "HLE"}, {"pcsx_rearmed_drc", "disabled"},
    {"pcsx_rearmed_memcard1", "shared"}, {"pcsx_rearmed_memcard2", "shared"},
    {"pcsx_rearmed_rgb32_output", "enabled"}, {"pcsx_rearmed_frameskip_type", "disabled"}};
static std::string saves;
static unsigned frames, width, height;
static size_t audioFrames, nonzeroAudio;
static uint64_t videoHash;
static bool pressed, optionsChanged;
static retro_pixel_format format;
static void log(enum retro_log_level, const char *fmt, ...) {
    va_list a; va_start(a, fmt); vfprintf(stderr, fmt, a); va_end(a);
}
static bool environment(unsigned cmd, void *data) {
    switch (cmd) {
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY: *(const char **)data = saves.c_str(); return true;
        case RETRO_ENVIRONMENT_GET_LOG_INTERFACE: ((retro_log_callback *)data)->log = log; return true;
        case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION: *(unsigned *)data = 2; return true;
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2:
            for (auto *o = ((retro_core_options_v2 *)data)->definitions; o && o->key; ++o)
                if (!options.count(o->key)) options[o->key] = o->default_value ? o->default_value : o->values[0].value;
            return true;
        case RETRO_ENVIRONMENT_GET_VARIABLE: {
            auto *v = (retro_variable *)data; auto it = options.find(v->key);
            v->value = it == options.end() ? nullptr : it->second.c_str(); return v->value != nullptr;
        }
        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE: *(bool *)data = optionsChanged; optionsChanged = false; return true;
        case RETRO_ENVIRONMENT_GET_JIT_CAPABLE: *(bool *)data = false; return true;
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
            format = *(retro_pixel_format *)data;
            return format == RETRO_PIXEL_FORMAT_XRGB8888;
        case RETRO_ENVIRONMENT_GET_CAN_DUPE: *(bool *)data = true; return true;
        case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS: return true;
        case RETRO_ENVIRONMENT_SET_GEOMETRY:
        case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
        case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
        case RETRO_ENVIRONMENT_SET_MEMORY_MAPS:
        case RETRO_ENVIRONMENT_SET_SERIALIZATION_QUIRKS:
        case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME: return true;
        default: return false;
    }
}
static void video(const void *data, unsigned w, unsigned h, size_t pitch) {
    if (!data) return;
    assert(format == RETRO_PIXEL_FORMAT_XRGB8888 && w && h && pitch >= w * 4);
    frames++; width = w; height = h; videoHash = 1469598103934665603ULL;
    for (unsigned y = 0; y < h; y++) for (unsigned x = 0; x < w * 4; x++) {
        videoHash ^= ((const uint8_t *)data)[y * pitch + x]; videoHash *= 1099511628211ULL;
    }
}
static size_t audio(const int16_t *data, size_t n) {
    audioFrames += n;
    for (size_t i = 0; i < n * 2; ++i) if (data[i]) nonzeroAudio++;
    return n;
}
static void sample(int16_t l, int16_t r) { int16_t data[] = {l, r}; audio(data, 1); }
static void poll() {}
static int16_t input(unsigned p, unsigned device, unsigned, unsigned id) {
    if (p || (device & RETRO_DEVICE_MASK) != RETRO_DEVICE_JOYPAD) return 0;
    if (id == RETRO_DEVICE_ID_JOYPAD_MASK) return pressed ? (1 << RETRO_DEVICE_ID_JOYPAD_B) : 0;
    return pressed && id == RETRO_DEVICE_ID_JOYPAD_B;
}
int main(int argc, char **argv) {
    assert(argc == 4); saves = argv[3]; std::filesystem::create_directories(saves);
    void *handle = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!handle) { fprintf(stderr, "%s\n", dlerror()); return 1; }
#define API(name) auto name = (decltype(&::name))dlsym(handle, #name); assert(name)
    API(retro_set_environment); API(retro_set_video_refresh); API(retro_set_audio_sample_batch);
    API(retro_set_audio_sample); API(retro_set_input_poll); API(retro_set_input_state);
    API(retro_init); API(retro_deinit); API(retro_load_game); API(retro_unload_game); API(retro_run);
    API(retro_serialize_size); API(retro_serialize); API(retro_unserialize); API(retro_get_memory_data);
    API(retro_get_system_av_info);
    retro_set_environment(environment); retro_set_video_refresh(video); retro_set_audio_sample_batch(audio);
    retro_set_audio_sample(sample); retro_set_input_poll(poll); retro_set_input_state(input); retro_init();
    retro_game_info game{}; game.path = argv[2]; assert(retro_load_game(&game));
    retro_system_av_info av{}; retro_get_system_av_info(&av); assert(av.timing.fps > 49 && av.timing.fps < 61);
    for (int i = 0; i < 120; ++i) retro_run();
    assert(frames > 60 && width == 320 && height == 240);
    options["pcsx_rearmed_neon_enhancement_enable"] = "enabled"; optionsChanged = true;
    for (int i = 0; i < 30; ++i) retro_run();
    assert(width == 640 && height == 480);
    options["pcsx_rearmed_neon_enhancement_enable"] = "disabled"; optionsChanged = true;
    for (int i = 0; i < 30; ++i) retro_run();
    assert(width == 320 && height == 240);
    auto *ram = (uint8_t *)retro_get_memory_data(RETRO_MEMORY_SYSTEM_RAM); assert(ram);
    const uint16_t released = ram[0x20002] | (ram[0x20003] << 8);
    const auto before = videoHash;
    std::vector<uint8_t> state(retro_serialize_size()); assert(state.size() > 256);
    assert(retro_serialize(state.data(), state.size()));
    pressed = true;
    for (int i = 0; i < 30; ++i) retro_run();
    const uint16_t down = ram[0x20002] | (ram[0x20003] << 8);
    fprintf(stderr, "PS1 fixture: pad released=%04x pressed=%04x, image=%llx -> %llx, frames=%u, audio=%zu/%zu\n",
            released, down, before, videoHash, frames, audioFrames, nonzeroAudio);
    assert((released & 0x4000) && !(down & 0x4000)); assert(videoHash != before);
    assert(audioFrames > 40000 && nonzeroAudio > 100);
    assert(retro_unserialize(state.data(), state.size()));
    assert((ram[0x20002] | (ram[0x20003] << 8)) == released);
    pressed = false;
    const auto framesBeforeRestore = frames;
    for (int i = 0; i < 30; ++i) retro_run();
    assert(frames >= framesBeforeRestore + 20 && videoHash == before);
    retro_unload_game(); retro_deinit();
    for (int i : {1, 2}) {
        const auto card = std::filesystem::path(saves) / ("pcsx-card" + std::to_string(i) + ".mcd");
        assert(std::filesystem::file_size(card) == 128 * 1024);
    }
    const auto card = std::filesystem::path(saves) / "pcsx-card1.mcd";
    auto read = [&]() { std::ifstream f(card, std::ios::binary); return std::string(std::istreambuf_iterator<char>(f), {}); };
    const auto saved = read(); assert(saved.find("EMUDEN-PERSIST-01") != std::string::npos);
    retro_init(); assert(retro_load_game(&game));
    for (int i = 0; i < 15; ++i) retro_run();
    retro_unload_game(); retro_deinit(); assert(read() == saved);
    printf("PASS: PS1 GPU, live 1x/2x/1x rendering, HLE boot, cross input, SPU audio, state restore and native card write/reopen persistence.\n");
}
