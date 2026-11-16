# PlayStation core

Upstream: https://github.com/libretro/pcsx_rearmed
Pinned commit: `7b0e8f8fadfbce3d170d195b9d9eecaabfa08c8e` (retrieved November 12, 2026).

Source is retained under `Source/`. PCSX core files carry GPL-2.0-or-later notices; dependencies retain their individual licenses. Full upstream COPYING, AUTHORS and dependency notices are preserved in EmuDen's offline notice bundle. This is a separate core from Azahar and does not change the owner's 3DS data.

`python3 Scripts/build-ps1-core.py` builds arm64 macOS (headless QA), iOS Simulator and iOS device frameworks with matching dSYMs. Clang/Xcode, Python 3 and make are required. Builds use DYNAREC=0/DRC_DISABLE, the NEON software GPU, CHD support and no physical CD drive support. The build copy changes the upstream Mach ptrace conditional to exclude interpreter builds. It asserts that ptrace/syscall/mprotect are absent from undefined symbols. No new JIT entitlement is used. Native game memory cards are configured as core-managed files inside a separate directory for each imported game.

No Sony firmware or commercial game data is included. Optional user BIOS imports are checked against the documented SCPH-5500/5501/5502 sizes and hashes. The fallback is the core's HLE implementation, with compatibility limits described in Settings.

`Scripts/make-ps1-homebrew.py` creates an original 4 KB PS-X executable with GPU primitives, PAD BIOS calls and a tiny original ADPCM tone. It is GPL-3.0-or-later and contains no extracted firmware, game code, artwork or audio. `Scripts/ps1-smoke.cpp` checks rendering, Cross input, nonzero audio and state restore on the Mac; Mac timings do not measure iPhone performance.

Documentation: https://docs.libretro.com/library/pcsx_rearmed/
