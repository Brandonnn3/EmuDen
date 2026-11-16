# Dolphin GC-only EmuDen28 frontend

Primary upstream: https://github.com/dolphin-emu/dolphin/tree/f84df02055ab9610feec48e65648cac5a3c098fa
Tag2609; exact portable source/dependencies, archive hash, patches, resource
policy and submodule pins are in source-manifest.json. Upstream COPYING,
LICENSES and dependency texts are retained in source and the148 offline notices.
No license exception, Apple acceptance or legal clearance is claimed.

The isolated derived source applies dolphin-generic-memtools.patch and
dolphin-ios-port.patch, then sanitize-dolphin-source.py. It omits unused Wii
factory-key/identity defaults and GC DSP/font/Wii resource blobs, with hashes
and names retained without removed bytes. No .git history enters the portable
archive. The original source/prototype and older releases remain preserved
outside this candidate. No proprietary firmware/game download occurred.

Scripts/build-gamecube-core.py performs fresh pinned CMake core/dependency
builds for arm64 iOS and Simulator. Generic Cached Interpreter and native Metal
are used; iOS executable allocation is rejected. CPU JIT/private brokers are
not enabled. Framework/symbol/build records are in GAMECUBE-CORE-BUILD-28.json.
A final normal CMake frontend rebuild enables real XFB-to-RAM copies for
homebrew compatibility against the freshly built unchanged static libraries.
AudioCommon's pinned unit is generated with a public PCM callback; AVAudioSourceNode
is provided by the app. No optional analytics/updates/Qt/CPU-JIT service ships.

GameCubeCore/Host/C ABI, Objective-C/Swift lifecycle/input/audio and original
PPC/GX/EXI diagnostics are corresponding source in Bridge/App/Scripts/Tests.
Register/protocol references are pinned Dolphin GX/EXI/SI/Boot sources and
libogc primary headers at ef718e2d7df5e5b1750a9e1a67c17350bdd30d3e; no libogc
library or console SDK is compiled/linked. Original guest code plus actual
EmuDen-player pixels/SI/status/card relaunch supplies the integration evidence.
Only original homebrew/owned QA Simulator were used. Native raw-card persistence
is not a retail save-file or retail compatibility/phone performance guarantee.
