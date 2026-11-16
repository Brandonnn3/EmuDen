// Development frontend for Dolphin. CPU JIT and executable allocation remain disabled on iOS.
#include "GameCubeCore.h"
#include "GameCubeHost.h"
#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstring>
#include <filesystem>
#include <optional>
#include <thread>
#include <mutex>
#include <array>
#include "AudioCommon/SoundStream.h"
#include "Common/Config/Config.h"
#include "Core/Boot/Boot.h"
#include "Core/BootManager.h"
#include "Core/Config/MainSettings.h"
#include "Core/Config/GraphicsSettings.h"
#include "Core/Core.h"
#include "Core/HW/GCPad.h"
#include "Core/HW/EXI/EXI_Device.h"
#include "Core/HW/Memmap.h"
#include "Core/HW/SI/SI_Device.h"
#include "Core/PowerPC/PowerPC.h"
#include "Core/State.h"
#include "Core/System.h"
#include "InputCommon/ControllerEmu/ControllerEmu.h"
#include "InputCommon/InputConfig.h"
#include "UICommon/UICommon.h"
#include "VideoCommon/VideoEvents.h"
#include "VideoCommon/Present.h"
#include "VideoCommon/AbstractGfx.h"
#include "VideoCommon/AbstractStagingTexture.h"
#include "VideoCommon/AbstractTexture.h"
#include "VideoCommon/VideoConfig.h"
#include "VideoCommon/FramebufferManager.h"

static bool initialized = false;
static std::atomic<uint32_t> buttons{0};
static std::atomic<float> stick_x{0}, stick_y{0};
static std::atomic<float> cstick_x{0}, cstick_y{0}, trigger_l{0}, trigger_r{0};
static std::atomic<bool> surface_dirty{true};
static Common::EventHook presentation;
static EmuDenGCCallbacks audio_callbacks{};
static std::mutex mixer_mutex;
static std::atomic<uint64_t> audio_frames{0};
static std::atomic<uint32_t> audio_peak{0};
static unsigned graphics_resolution = 1, graphics_filtering = 0;
static AnisotropicFilteringMode graphics_anisotropy = AnisotropicFilteringMode::Default;

static void ApplyGraphics() {
    Config::SetCurrent(Config::GFX_EFB_SCALE, int(graphics_resolution));
    Config::SetCurrent(Config::GFX_ENHANCE_FORCE_TEXTURE_FILTERING, TextureFilteringMode(graphics_filtering));
    Config::SetCurrent(Config::GFX_ENHANCE_MAX_ANISOTROPY, graphics_anisotropy);
}

void EmuDenGC_ConfigureGraphics(unsigned resolution, unsigned filtering, unsigned anisotropy) {
    graphics_resolution = std::clamp(resolution, 1u, 4u);
    graphics_filtering = filtering <= 2 ? filtering : 0;
    switch (anisotropy) {
        case 1: graphics_anisotropy = AnisotropicFilteringMode::Force1x; break;
        case 2: graphics_anisotropy = AnisotropicFilteringMode::Force2x; break;
        case 4: graphics_anisotropy = AnisotropicFilteringMode::Force4x; break;
        case 8: graphics_anisotropy = AnisotropicFilteringMode::Force8x; break;
        case 16: graphics_anisotropy = AnisotropicFilteringMode::Force16x; break;
        default: graphics_anisotropy = AnisotropicFilteringMode::Default;
    }
    if (initialized) {
        Core::CPUThreadGuard guard(Core::System::GetInstance());
        ApplyGraphics();
        // Apply while paused too; a static scene may not emit another GX frame event.
        if (g_gfx && g_framebuffer_manager) {
            g_Config.Refresh();
            g_Config.VerifyValidity();
            CheckForConfigChanges();
        }
    }
}

class EmuDenPCMStream final : public SoundStream {
    std::atomic<bool> running{false}, stopping{false};
    std::atomic<int> volume{100};
    std::thread worker;
public:
    bool Init() override {
        if (!audio_callbacks.audio) return false;
        worker = std::thread([this, callbacks = audio_callbacks] {
            std::array<int16_t, 960> pcm{};
            auto deadline = std::chrono::steady_clock::now();
            while (!stopping.load()) {
                deadline += std::chrono::milliseconds(10);
                if (running.load()) {
                    { std::lock_guard lock(mixer_mutex); GetMixer()->Mix(pcm.data(), 480); }
                    uint32_t peak = 0;
                    for (auto& sample : pcm) {
                        sample = static_cast<int16_t>(int(sample) * volume.load() / 100);
                        peak = std::max(peak, uint32_t(std::abs(int(sample))));
                    }
                    audio_frames.fetch_add(480); audio_peak.store(std::max(audio_peak.load(), peak));
                    callbacks.audio(callbacks.context, pcm.data(), 480);
                }
                std::this_thread::sleep_until(deadline);
                if (deadline + std::chrono::milliseconds(100) < std::chrono::steady_clock::now())
                    deadline = std::chrono::steady_clock::now();
            }
        });
        return true;
    }
    bool SetRunning(bool enabled) override { running = enabled; return true; }
    void SetVolume(int percent) override { volume = std::clamp(percent, 0, 100); }
    ~EmuDenPCMStream() override { stopping = true; if (worker.joinable()) worker.join(); }
};
SoundStream* EmuDenGC_CreateSoundStream() { return new EmuDenPCMStream(); }

bool EmuDenGC_Start(const char* rom, const char* directory, void* layer, EmuDenGCCallbacks callbacks) {
    if (initialized || !rom || !directory) return false;
    GameCubeResetHostStop();
    buttons = 0; stick_x = 0; stick_y = 0;
    cstick_x = 0; cstick_y = 0; trigger_l = 0; trigger_r = 0;
    surface_dirty = true;
    audio_callbacks = callbacks; audio_frames = 0; audio_peak = 0;
    UICommon::SetUserDirectory(directory);
    UICommon::Init();
    initialized = true;
    Config::SetBase(Config::MAIN_CPU_CORE, PowerPC::CPUCore::CachedInterpreter);
    Config::SetBase(Config::MAIN_FASTMEM, false);
    Config::SetBase(Config::MAIN_CPU_THREAD, false);
    Config::SetBase(Config::MAIN_SKIP_IPL, true);
    Config::SetBase(Config::MAIN_DSP_HLE, true);
    // Each imported game owns its Dolphin user directory and native raw card.
    Config::SetBase(Config::MAIN_SLOT_A, ExpansionInterface::EXIDeviceType::MemoryCard);
    Config::SetBase(Config::MAIN_GFX_BACKEND, std::string("Metal"));
    Config::SetBase(Config::GFX_ASPECT_RATIO, AspectMode::Stretch);
    Config::SetBase(Config::GFX_HACK_SKIP_DUPLICATE_XFBS, false);
    // Preserve real XFB contents for software/VI reads as well as native GX copies.
    Config::SetBase(Config::GFX_HACK_SKIP_XFB_COPY_TO_RAM, false);
    ApplyGraphics();
    Config::SetBase(Config::MAIN_AUDIO_BACKEND, std::string(callbacks.audio ? "EmuDen PCM" : "No Audio Output"));
    Config::SetBase(Config::GetInfoForSIDevice(0), SerialInterface::SIDEVICE_GC_CONTROLLER);
    WindowSystemInfo wsi;
    wsi.render_surface = layer;  // Caller owns the CAMetalLayer; no macOS NSView preparation.
    UICommon::InitControllers(wsi);
    auto* pad = Pad::GetConfig()->GetController(0);
    if (!pad) { EmuDenGC_Stop(); return false; }
    pad->SetInputOverrideFunction([](std::string_view group, std::string_view control, double) -> std::optional<double> {
        const auto down = [](unsigned n) -> double { return (buttons.load() & (1u << n)) ? 1.0 : 0.0; };
        if (group == "Buttons") {
            if (control == "A") return down(0);
            if (control == "B") return down(8);
            if (control == "X") return down(1);
            if (control == "Y") return down(9);
            if (control == "Z") return down(12);
            if (control == "Start") return down(3);
        } else if (group == "D-Pad") {
            if (control == "Up") return down(4);
            if (control == "Down") return down(5);
            if (control == "Left") return down(6);
            if (control == "Right") return down(7);
        } else if (group == "Main Stick") {
            const float x = stick_x.load(), y = stick_y.load();
            // Pinned Dolphin overrides shaped axes, not directional bindings.
            if (control == "X") return x;
            if (control == "Y") return y;
        } else if (group == "C-Stick") {
            if (control == "X") return cstick_x.load();
            if (control == "Y") return cstick_y.load();
        } else if (group == "Triggers") {
            if (control == "L") return down(10);
            if (control == "R") return down(11);
            if (control == "L-Analog") return std::max(down(10), double(trigger_l.load()));
            if (control == "R-Analog") return std::max(down(11), double(trigger_r.load()));
        }
        return 0.0;
    });
    if (callbacks.presented) {
        presentation = GetVideoEvents().after_present_event.Register([callbacks](PresentInfo& info) {
            callbacks.presented(callbacks.context, info.frame_count, info.frame_buffer_width, info.frame_buffer_height);
        });
    }
    if (!BootManager::BootCore(Core::System::GetInstance(), BootParameters::GenerateFromFile(rom), wsi)) {
        EmuDenGC_Stop(); return false;
    }
    return true;
}

bool EmuDenGC_Pump() {
    if (!initialized) return false;
    auto& system = Core::System::GetInstance();
    Core::HostDispatchJobs(system);
    if (Core::IsRunning(system) && surface_dirty.exchange(false)) {
        Core::CPUThreadGuard guard(system);
        if (g_presenter) {
            g_presenter->ResizeSurface();
            g_presenter->ClearLastXfbId();
        }
    }
    return !GameCubeHostStopRequested();
}
void EmuDenGC_Resize() { surface_dirty = true; }
void EmuDenGC_Button(unsigned button, bool pressed) {
    if (button >= 32) return;
    const auto mask = 1u << button;
    if (pressed) buttons.fetch_or(mask); else buttons.fetch_and(~mask);
}
void EmuDenGC_Stick(float x, float y) {
    if (!std::isfinite(x) || !std::isfinite(y)) { stick_x = 0; stick_y = 0; return; }
    stick_x = std::clamp(x, -1.0f, 1.0f); stick_y = std::clamp(y, -1.0f, 1.0f);
}
void EmuDenGC_CStick(float x, float y) {
    if (!std::isfinite(x) || !std::isfinite(y)) { cstick_x = 0; cstick_y = 0; return; }
    cstick_x = std::clamp(x, -1.0f, 1.0f); cstick_y = std::clamp(y, -1.0f, 1.0f);
}
void EmuDenGC_Triggers(float left, float right) {
    trigger_l = std::isfinite(left) ? std::clamp(left, 0.0f, 1.0f) : 0;
    trigger_r = std::isfinite(right) ? std::clamp(right, 0.0f, 1.0f) : 0;
}
void EmuDenGC_Pause(bool paused) {
    if (paused) { buttons = 0; EmuDenGC_Stick(0,0); EmuDenGC_CStick(0,0); EmuDenGC_Triggers(0,0); }
    if (initialized) Core::SetState(Core::System::GetInstance(), paused ? Core::State::Paused : Core::State::Running);
}
bool EmuDenGC_SaveState(const char* path) {
    auto& system = Core::System::GetInstance();
    if (!initialized || !path || !Core::IsRunning(system)) return false;
    std::error_code ec;
    const auto previous = std::filesystem::last_write_time(path, ec);
    { std::lock_guard lock(mixer_mutex); Core::CPUThreadGuard guard(system); State::SaveAs(system, path); }
    const auto end = std::chrono::steady_clock::now() + std::chrono::seconds(10);
    while (std::chrono::steady_clock::now() < end) {
        EmuDenGC_Pump();
        const auto now = std::filesystem::last_write_time(path, ec);
        if (!ec && now != previous && std::filesystem::file_size(path, ec) > 1024 && !ec) return true;
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
    return false;
}
bool EmuDenGC_LoadState(const char* path) {
    auto& system = Core::System::GetInstance();
    if (!initialized || !path || !Core::IsRunning(system)) return false;
    std::lock_guard lock(mixer_mutex);
    Core::CPUThreadGuard guard(system);
    bool loaded = false;
    State::SetOnAfterLoadCallback([&] { loaded = true; });
    State::LoadAs(system, path);
    State::SetOnAfterLoadCallback({});
    return loaded;
}
EmuDenGCDemoStatus EmuDenGC_DemoStatus() {
    auto& system = Core::System::GetInstance();
    if (!initialized || !Core::IsRunning(system)) return {};
    Core::CPUThreadGuard guard(system);
    auto& mem = system.GetMemory();
    return {mem.Read_U32(0x10000), mem.Read_U32(0x10004), mem.Read_U32(0x10008), mem.Read_U32(0x100000), mem.Read_U32(0x1000c)};
}
EmuDenGCAudioStatus EmuDenGC_AudioStatus() { return {audio_frames.load(), audio_peak.load()}; }
EmuDenGCGraphicsStatus EmuDenGC_GraphicsStatus() {
    auto& system = Core::System::GetInstance();
    if (!initialized || !Core::IsRunning(system)) return {};
    Core::CPUThreadGuard guard(system);
    return {unsigned(Config::Get(Config::GFX_EFB_SCALE)), unsigned(Config::Get(Config::GFX_ENHANCE_FORCE_TEXTURE_FILTERING)),
        int(Config::Get(Config::GFX_ENHANCE_MAX_ANISOTROPY)),
        g_framebuffer_manager ? g_framebuffer_manager->GetEFBWidth() : 0,
        g_framebuffer_manager ? g_framebuffer_manager->GetEFBHeight() : 0};
}
bool EmuDenGC_CopyPreview(uint8_t* bytes, size_t capacity, unsigned* width, unsigned* height) {
    auto& system = Core::System::GetInstance();
    if (!initialized || !width || !height || !Core::IsRunning(system)) return false;
    Core::CPUThreadGuard guard(system);
    if (!g_presenter || !g_gfx) return false;
    const auto* texture = g_presenter->GetXFBForPreview();
    const auto rect = g_presenter->GetXFBPreviewRect();
    if (!texture || texture->GetFormat() != AbstractTextureFormat::RGBA8 ||
        rect.GetWidth() <= 0 || rect.GetHeight() <= 0 || rect.GetWidth() > 4096 || rect.GetHeight() > 4096) return false;
    *width = rect.GetWidth(); *height = rect.GetHeight();
    if (!bytes) return true;
    const size_t stride = *width * 4;
    if (capacity < stride * *height) return false;
    auto copy = g_gfx->CreateStagingTexture(StagingTextureType::Readback,
        TextureConfig(*width, *height, 1, 1, 1, AbstractTextureFormat::RGBA8, 0, AbstractTextureType::Texture_2DArray));
    if (!copy) return false;
    copy->CopyFromTexture(texture, rect, 0, 0, copy->GetRect());
    copy->Flush();
    if (!copy->Map()) return false;
    for (unsigned y = 0; y < *height; ++y)
        std::memcpy(bytes + y * stride, copy->GetMappedPointer() + y * copy->GetMappedStride(), stride);
    copy->Unmap();
    return true;
}
void EmuDenGC_Stop() {
    if (!initialized) return;
    auto& system = Core::System::GetInstance();
    Core::Stop(system);
    Core::Shutdown(system);
    presentation = {};
    UICommon::ShutdownControllers();
    UICommon::Shutdown();
    initialized = false;
    buttons = 0;
    audio_callbacks = {};
}
