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
#include "Core/HW/EXI/EXI_Device.h"
#include "Core/HW/Memmap.h"
#include "Core/HW/SI/SI_Device.h"
#include "Core/PowerPC/PowerPC.h"
#include "Core/State.h"
#include "Core/System.h"
#include "InputCommon/ControllerEmu/ControllerEmu.h"
#include "InputCommon/InputConfig.h"
#include "UICommon/UICommon.h"
#include "VideoCommon/FrameDumper.h"
#include "VideoCommon/FramebufferManager.h"
#include "VideoCommon/BPMemory.h"
#include "VideoCommon/XFMemory.h"
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

int main(int argc,char**argv) {
 check(argc==3,"Usage: gx-card-smoke original.dol fresh-user-directory");
 check(!std::filesystem::exists(argv[2]),"Use fresh original-homebrew QA user data");
 UICommon::SetUserDirectory(argv[2]);UICommon::Init();
 Config::SetBase(Config::MAIN_CPU_CORE,PowerPC::CPUCore::CachedInterpreter);
 Config::SetBase(Config::MAIN_FASTMEM,false);Config::SetBase(Config::MAIN_CPU_THREAD,false);
 Config::SetBase(Config::MAIN_SKIP_IPL,true);Config::SetBase(Config::MAIN_DSP_HLE,true);
 Config::SetBase(Config::MAIN_SLOT_A,ExpansionInterface::EXIDeviceType::MemoryCard);
 Config::SetBase(Config::MAIN_GFX_BACKEND,std::string("Metal"));
 Config::SetBase(Config::MAIN_AUDIO_BACKEND,std::string("No Audio Output"));
 Config::SetBase(Config::GFX_HACK_SKIP_DUPLICATE_XFBS,false);
 Config::SetBase(Config::GFX_HACK_SKIP_XFB_COPY_TO_RAM,false);
 WindowSystemInfo wsi;UICommon::InitControllers(wsi);auto& system=Core::System::GetInstance();
 cleanup=[&]{Core::Stop(system);Core::Shutdown(system);UICommon::ShutdownControllers();UICommon::Shutdown();};
 check(BootManager::BootCore(system,BootParameters::GenerateFromFile(argv[1]),wsi),"Original DOL starts");
 auto read=[&](u32 address){Core::CPUThreadGuard guard(system);return system.GetMemory().Read_U32(address);};
 auto end=std::chrono::steady_clock::now()+std::chrono::seconds(5);
 while(std::chrono::steady_clock::now()<end){Core::HostDispatchJobs(system);std::this_thread::sleep_for(std::chrono::milliseconds(20));}
 std::fprintf(stderr,"Guest marker=%08x prior-card=%08x pad=%08x/%08x pixel=%08x center=%08x\n",read(0x10000),read(0x10004),read(0x10008),read(0x1000c),read(0x100000),read(0x100000+(120*320+160)*2));
 { Core::CPUThreadGuard guard(system); std::fprintf(stderr,"EFB center=%08x near-depth=%f; BP gen=%08x blend=%08x z=%08x; XF channels=%08x color=%08x\n",g_framebuffer_manager->PeekEFBColor(160,120),g_framebuffer_manager->PeekEFBDepth(160,120),bpmem.genMode.hex,bpmem.blendmode.hex,bpmem.zmode.hex,xfmem.numChan.hex,xfmem.color[0].hex); }
 const std::string image=std::string(argv[2])+"/gx.png";g_frame_dumper->SaveScreenshot(image);
 for(int i=0;i<100&&!std::filesystem::exists(image);++i){Core::HostDispatchJobs(system);{Core::CPUThreadGuard guard(system);g_frame_dumper->FlushFrameDump();}std::this_thread::sleep_for(std::chrono::milliseconds(30));}
 cleanup();cleanup={};std::fprintf(stderr,"Original GX/card diagnostic stopped and native card flushed\n");return 0;
}
