// Original headless integration test. No proprietary firmware or retail assets.
#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <functional>
#include <string>
#include <thread>
#include "Common/Config/Config.h"
#include "Common/FileUtil.h"
#include "Common/Logging/LogManager.h"
#include "Common/WindowSystemInfo.h"
#include "Core/Boot/Boot.h"
#include "Core/BootManager.h"
#include "Core/Config/MainSettings.h"
#include "Core/Config/GraphicsSettings.h"
#include "Core/Core.h"
#include "Core/Host.h"
#include "Core/HW/GCPad.h"
#include "Core/HW/Memmap.h"
#include "Core/HW/SI/SI_Device.h"
#include "Core/PowerPC/PowerPC.h"
#include "Core/State.h"
#include "Core/System.h"
#include "InputCommon/ControllerEmu/ControllerEmu.h"
#include "InputCommon/InputConfig.h"
#include "UICommon/UICommon.h"
#include "VideoCommon/FrameDumper.h"
#include "VideoCommon/Present.h"

std::vector<std::string> Host_GetPreferredLocales() { return {}; }
bool Host_UIBlocksControllerState() { return false; }
bool Host_RendererHasFocus() { return true; }
bool Host_RendererHasFullFocus() { return true; }
bool Host_RendererIsFullscreen() { return false; }
bool Host_TASInputHasFocus() { return false; }
void Host_Message(HostMessageID) {}
void Host_PPCSymbolsChanged() {}
void Host_PPCBreakpointsChanged() {}
void Host_RequestRenderWindowSize(int, int) {}
void Host_UpdateDisasmDialog() {}
void Host_JitCacheInvalidation() {}
void Host_JitProfileDataWiped() {}
void Host_UpdateTitle(const std::string& s) { std::fprintf(stderr, "%s\n", s.c_str()); }
void Host_YieldToUI() {}
void Host_TitleChanged() {}
void Host_UpdateDiscordClientID(const std::string&) {}
bool Host_UpdateDiscordPresenceRaw(const std::string&, const std::string&, const std::string&,
    const std::string&, const std::string&, const std::string&, int64_t, int64_t, int, int) { return false; }
std::unique_ptr<GBAHostInterface> Host_CreateGBAHost(std::weak_ptr<HW::GBA::Core>) { return nullptr; }

static std::function<void()> cleanup;
static void check(bool ok, const char* message) {
    if (!ok) {
        std::fprintf(stderr, "FAIL: %s\n", message);
        if (cleanup) cleanup();
        std::exit(1);
    }
}

int main(int argc, char** argv) {
    check(argc == 3 || argc == 4, "Usage: gamecube-smoke original.dol fresh-user-directory [Metal]");
    const bool metal = argc == 4 && std::string_view(argv[3]) == "Metal";
    check(argc == 3 || metal, "The optional render check uses Metal");
    check(!std::filesystem::exists(argv[2]), "Use a fresh test user directory; never an owner's saves");
    UICommon::SetUserDirectory(argv[2]);
    UICommon::Init();
    Common::Log::LogManager::GetInstance()->SetEnable(Common::Log::LogType::VIDEO, true);
    Common::Log::LogManager::GetInstance()->SetConfigLogLevel(Common::Log::LogLevel::LDEBUG);
    Config::SetBase(Config::MAIN_CPU_CORE, PowerPC::CPUCore::CachedInterpreter);
    Config::SetBase(Config::MAIN_FASTMEM, false);
    Config::SetBase(Config::MAIN_CPU_THREAD, false);
    Config::SetBase(Config::MAIN_SKIP_IPL, true);
    Config::SetBase(Config::MAIN_DSP_HLE, true);
    Config::SetBase(Config::MAIN_GFX_BACKEND, std::string(metal ? "Metal" : "Null"));
    Config::SetBase(Config::GFX_HACK_SKIP_DUPLICATE_XFBS, false);
    Config::SetBase(Config::MAIN_AUDIO_BACKEND, std::string("No Audio Output"));
    Config::SetBase(Config::GetInfoForSIDevice(0), SerialInterface::SIDEVICE_GC_CONTROLLER);
    WindowSystemInfo wsi;
    UICommon::InitControllers(wsi);
    std::atomic<bool> pressed{false}, analog{false};
    Pad::GetConfig()->GetController(0)->SetInputOverrideFunction(
        [&](const auto& group, const auto& control, double) -> std::optional<double> {
            if (group == "Buttons" && control == "A") return pressed.load() ? 1.0 : 0.0;
            if (analog.load()) {
                if (group == "Main Stick" && control == "X") return -0.7;
                if (group == "Main Stick" && control == "Y") return -0.3;
                if (group == "C-Stick" && control == "X") return 0.5;
                if (group == "C-Stick" && control == "Y") return 0.6;
                if (group == "Triggers" && control == "L-Analog") return 0.35;
                if (group == "Triggers" && control == "R-Analog") return 0.65;
            }
            return 0.0;
        });
    auto& system = Core::System::GetInstance();
    cleanup = [&] {
        Core::Stop(system);
        Core::Shutdown(system);
        UICommon::ShutdownControllers();
        UICommon::Shutdown();
    };
    check(BootManager::BootCore(system, BootParameters::GenerateFromFile(argv[1]), wsi), "DOL accepted");
    auto wait = [&](auto predicate, int seconds = 15) {
        const auto end = std::chrono::steady_clock::now() + std::chrono::seconds(seconds);
        while (std::chrono::steady_clock::now() < end) {
            Core::HostDispatchJobs(system);
            if (Core::GetState(system) == Core::State::Running && predicate()) return true;
            std::this_thread::sleep_for(std::chrono::milliseconds(20));
        }
        return false;
    };
    auto read = [&](u32 address) { Core::CPUThreadGuard guard(system); return system.GetMemory().Read_U32(address); };
    check(wait([&] { return read(0x10000) == 0x454D5544; }), "original PowerPC program executed");
    check(wait([&] { return read(0x100000) == 0x307030A0; }), "original framebuffer written");
    if (metal) {
        const bool presented = wait([&] { Core::CPUThreadGuard guard(system); return g_presenter->FrameCount() > 0; });
        std::fprintf(stderr, "Metal produced an XFB frame: %s\n", presented ? "yes" : "no");
        check(presented, "Metal produced an XFB frame");
    }
    auto screenshot = [&](const char* name) {
        if (!metal) return;
        const std::string path = std::string(argv[2]) + "/" + name + ".png";
        g_frame_dumper->SaveScreenshot(path);
        check(wait([&] {
            // This VI-only fixture has no GX frame-end command to flush readbacks.
            { Core::CPUThreadGuard guard(system); g_frame_dumper->FlushFrameDump(); }
            return std::filesystem::exists(path) && std::filesystem::file_size(path) > 100;
        }), "Metal framebuffer screenshot saved");
    };
    screenshot("released");
    pressed = true;
    check(wait([&] { return (read(0x10008) & 0x01000000) != 0; }), "emulated SI sees A button");
    check(wait([&] { return read(0x100000) == 0xB060B090; }), "A button changes framebuffer pixels");
    screenshot("pressed");
    pressed = false;
    check(wait([&] { return read(0x100000) == 0x307030A0; }), "button release reaches emulated program");
    analog = true;
    const bool analog_seen = wait([&] {
        const u32 high = read(0x10008), low = read(0x1000c);
        const auto main_x = (high >> 8) & 255, main_y = high & 255;
        const auto c_x = (low >> 24) & 255, c_y = (low >> 16) & 255;
        const auto left = (low >> 8) & 255, right = low & 255;
        return main_x < 112 && main_y < 128 && c_x > 144 && c_y > 144 &&
               left > 32 && left < 220 && right > left + 20 && right < 240 &&
               ((high >> 16) & 0x60) == 0;
    });
    std::fprintf(stderr, "Guest analog words: high=%08x low=%08x\n", read(0x10008), read(0x1000c));
    check(analog_seen, "guest SI mode3 sees both sticks and distinct partial analog triggers without digital clicks");
    analog = false;
    check(wait([&] {
        const u32 high = read(0x10008), low = read(0x1000c);
        const auto centered = [](u32 n) { return n >= 120 && n <= 136; };
        return centered((high >> 8) & 255) && centered(high & 255) &&
               centered((low >> 24) & 255) && centered((low >> 16) & 255) && (low & 0xffff) == 0;
    }), "guest SI sees both sticks re-centered and analog triggers fully released");
    const std::string state_path = std::string(argv[2]) + "/emuden-original.state";
    { Core::CPUThreadGuard guard(system); State::SaveAs(system, state_path); }
    check(wait([&] { return std::filesystem::exists(state_path) && std::filesystem::file_size(state_path) > 1024; }), "state saved to disk");
    { Core::CPUThreadGuard guard(system); system.GetMemory().Write_U32(0, 0x10000); }
    check(read(0x10000) == 0, "state test memory changed");
    { Core::CPUThreadGuard guard(system); State::LoadAs(system, state_path); }
    check(wait([&] { return read(0x10000) == 0x454D5544; }), "state restored program memory");
    const auto restored_counter = read(0x10004);
    check(wait([&] { return read(0x10004) != restored_counter; }), "program continues after restore");
    cleanup();
    cleanup = {};
    std::fprintf(stderr, "PASS: original GameCube PowerPC execution, framebuffer memory, SI input/release and saved-state restore. Extended original SI fixture verifies both sticks and partial analog-trigger release in the pinned Host core. No EmuDen frontend mapping, GX, native-card or phone claim.\n");
    return 0;
}
