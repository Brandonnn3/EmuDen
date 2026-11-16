# Build25 — internal 3DS and PS1 artwork beta

On November13 the owner authorized internal TestFlight distribution and chose
3DS + PS1 now, with GameCube later. This supersedes the earlier plan to hold25
for GameCube. Public App Store release remains held. No phone test is claimed.

This candidate preserves the sanitized build22–24 runtime dependencies,95
complete offline notices, age-service timeout, native saves, per-platform state
history, widgets and controller/touch landscape behavior. GameCube research
source remains preserved, but EMUDEN_EXPERIMENTAL_GAMECUBE=NO is mandatory for
this archive. No Dolphin framework or GameCube demo is embedded, and archive
embedding of the experimental core remains blocked.

Artwork25 supports an optional user-selected HTTPS cover folder, original
cover-front tiles, corrected catalog refreshes and persistent cover priority:
manual image, selected catalog portrait, then original box-art fallback.
Scene-crop catalog placeholders yield to boxes. Backgrounds remain independent,
cached images work offline, and no provider is configured by default. Earlier
approved portraits and every generated master/public URL remain preserved.

Verified before packaging:33 focused artwork tests, native production storage
and priority/persistence checks, a50.089-second source-entry/offline/disconnect
scenario, plus Simulator and unsigned arm64 iOS builds. Exact retained evidence
is under build/Build25-Original-Covers, Build25-Cover-Fronts and
Build25-Restore-Portraits. Distribution evidence is recorded separately in
build/Build25-Distribution and TestFlight/STATUS.md; do not infer upload success
from a development archive or unsigned build.

PS1 accepts CHD v5, one flat CUE with every referenced BIN (folder or selected
together), and PS-X EXE homebrew. Raw BIN alone, PS1 ISO/PBP/M3U, disc swapping
and analog-only games are unsupported in this phase.3DS uses the existing
compatible decrypted formats. No commercial games, proprietary BIOS or owner
data are included.

Rebuild using BUILD-22.md's mandatory sanitized3DS/OpenSSL3 inputs and
BUILD-24.md's pinned interpreter-only PCSX recipe. Build the Emulator scheme in
Release with EMUDEN_EXPERIMENTAL_GAMECUBE=NO. Local Vendor symlinks are build
conveniences, not source-package inputs. package-testflight-source.py includes
the exact sanitized upstream archives, dependency sources, patches, tests,
resources and notices, excluding contacts, signing credentials, user files and
compiled cores. Deliver the matching25 source package to internal recipients.

Internal upload is authorized; public release, source/public-policy changes,
agreements and legal classification are not approved by technical checks.
