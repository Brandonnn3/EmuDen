// EmuDen's non-Qt host callbacks for the pinned Dolphin core.
#include "GameCubeHost.h"
#include <atomic>
#include <cstdio>
#include "Core/Host.h"

static std::atomic<bool> stop_requested{false};
bool GameCubeHostStopRequested() { return stop_requested.load(); }
void GameCubeResetHostStop() { stop_requested = false; }
std::vector<std::string> Host_GetPreferredLocales() { return {}; }
bool Host_UIBlocksControllerState() { return false; }
bool Host_RendererHasFocus() { return true; }
bool Host_RendererHasFullFocus() { return true; }
bool Host_RendererIsFullscreen() { return false; }
bool Host_TASInputHasFocus() { return false; }
void Host_Message(HostMessageID id) { if (id == HostMessageID::WMUserStop) stop_requested = true; }
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
