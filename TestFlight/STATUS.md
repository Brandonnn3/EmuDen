# Build19 — submission candidate

The owner is testing18 on their phone. Build19 has a signed development archive with the new app-only entitlements and four matching real dSYMs,67passing domain tests,2tooling tests, release-control/save/UI coverage and two verified repeatable local StoreKit tips. A genuine single-screen background capture has a fresh timestamp and valid payload checksum. It changes release controls, not the core or phone performance.

The AppStoreConnect0.1.0 draft has listing text/private Apple review information, no sign-in, manual release, free US-only availability, subtitle/categories and privacy URL. ProductInteraction is configured as functionality/linked/no tracking; OtherData details/label publication, age questionnaire, rights decision and final screenshots/build selection remain. No app upload, review submission or new paid agreement occurred. CLI public export still needs working distribution signing; the development archive is not itself a signed public IPA.

Matching source19 is being packaged for publication. Seven native captures are prepared (iPhone/Duo/iPad); the broader iPad preview-animation wait timed out and is retained as a validation limit. The generated artwork and older signed releases/source remain preserved. Rights/branding and actual GPL/store distribution questions are still recorded; no Apple/legal clearance is claimed. See [submission plan](Submission-Plan.md), [build19 details](../Docs/BUILD-19.md) and [review packet](../Docs/Legal/RELEASE-19-REVIEW-PACKET.md).

---

# Public release and build 18 preparation — 11 November 2026

**Public App Store submission remains unconfirmed.** The owner authorized GPL-3.0-or-later for original EmuDen source contributions and public source/support publication, while keeping the generated images. Matching build-17 source is public and its anonymous download checksum is verified. Build 18 adds save history, queued background saving, periodic checkpoints, offline dependency notices and public policy/source links. Build 18 is signed and locally validated with four real dSYMs; matching source is public with anonymous checksum verification, and the support/privacy/source Site is public with nine verified paths. These technical checks are not Apple approval.

Generated artwork, archived builds 14–17 and their matching packages remain preserved. Keeping artwork does not establish publisher rights. Distribution terms, artwork basis, accurate privacy/export declarations and final release-device/review checks remain recorded in AppStoreReadiness.json. The artwork automation remains paused. Project QA Simulator data was moved onto the Samsung T7 after internal-disk exhaustion; original Simulator paths are retained as links. The original Duo Simulator was not moved.

Run `python3 Scripts/validate-app-store-readiness.py` for the actual evidence status. It deliberately distinguishes technical internal-beta packaging from public-release decisions. [Review and primary sources](../Docs/Legal/REVIEW-2026-11-11.md).

---

# Build 18 — dated save history

Pause → **Save history** provides thumbnails and dates for the latest **10 Quick Saves and 3 automatic points** per game. Load an earlier point with confirmation. Quick Load retains its one-step latest-manual behavior. The newest compatible manual/automatic point is offered on startup.

Periodic Automatic save points default on every five minutes of active play and can be disabled in Player settings. Background/exit capture stays enabled; an in-flight save/load now finishes before a background resume capture is attempted. Capturing briefly pauses play, and OS termination/force-quit/storage failure can still prevent completion. Native in-game saves remain separate; core/system-resource changes can make older snapshots unavailable without deleting them. No missing state on the physical phone has been diagnosed or recovered. Public policy/source pages are at https://emuden-support.headyopossum2.chatgpt.site; all nine authored pages/assets were checked anonymously, accounting for disclosed Cloudflare security-script injection.

- Signed archive: `build/TestFlight/EmuDen-0.1.0-18.xcarchive`.
- Matching source: `build/TestFlight/EmuDen-0.1.0-18-source.tar.gz` and https://github.com/Brandonnn3/EmuDen/releases/tag/v0.1.0-build.18.
- Final evidence: `build/TestFlight/Build18-PreparationReport.json`.
- [Implementation and limits](../Docs/BUILD-18.md).

62 domain tests, two tooling checks, the passing Duo UI scenarios and a native single-screen background-capture check provide the current evidence. The latter verifies a new timestamp and payload checksum after a real app switch with periodic saving disabled. Secondary GUI retries and the cold Simulator poll timeout remain recorded. The five-minute production interval is unit-tested; the live periodic test uses a Simulator-only short interval. Only 3DS is playable. The emulator core and existing generated images are unchanged. There is no new physical-phone performance claim or App Store/TestFlight upload in this preparation.

---

# Build 17 — per-game graphics, timing and native widgets

**EmuDen 0.1.0 (17)** is signed and locally validated for internal TestFlight preparation. Games can keep independent graphics profiles. Resolution and texture sampling apply live when play resumes; optional automatic quality, known-shader preparation, per-title cache management, frame timing and picture balance provide more control. Automatic quality and startup preparation are opt-in. Dark Moon's reported hitch was already at native 1×, so no resolution-based fix or new phone FPS gain is claimed.

- Archive: `build/TestFlight/EmuDen-0.1.0-17.xcarchive`.
- Matching source: `build/TestFlight/EmuDen-0.1.0-17-source.tar.gz`.
- Preparation report: `build/TestFlight/Build17-PreparationReport.json`.
- [Implementation and limits](../Docs/BUILD-17.md) · [actual settings/widget captures](../Docs/Preview/Build17-README.md).

The WidgetKit extension supplies Continue Playing (small/medium) and Recent Games (medium/large), using cached cinematic art and a bounded local App Group snapshot. The extension has no network fetches. Game links validate exact routes, handle missing games and use the existing resume-save/close flow when switching. Both targets' device signatures and provisioning profiles contain the same App Group. Settings previews use the actual shared content views; native Home Screen pinning and physical clear/tinted appearance remain device checks.

The Mii settings portrait now accepts a local image with persistence/reset and a separate resource-readiness badge. A shared face-resource archive does not contain a personal Mii avatar; this is an image chooser rather than automatic Mii rendering. The avatar is excluded from the widget snapshot and artwork host.

**56 domain tests and four distinct UI scenarios have passing latest results**, covering profiles, malformed input, cache isolation/symlinks, quality hysteresis, layout balance, widget routes and validated artwork cache reads without networking; avatar persistence/reset, outer-display touch mapping, graphics-profile/widget previews and URL launch/resume/missing-game handling. A separate active-session URL integration check verifies save-before-switch, both resume checksums and the shared widget snapshot. Visual review caught large-widget clipping; the corrected preview passed another targeted run. Earlier attempts are retained, including system URL confirmation and XCTest cold-relaunch assumptions. The Duo Simulator stays portrait after rotation requests, so live landscape and folding remain unverified.

The final actual Mario Golf renderer starts at 3×, switches to 1×, 2×/Smooth and 3×/Game default, then completes 841 frames with state capture/restore. Top/lower PNG dimensions verify all scales; the post-restore Mii scene was visually inspected. An initial test-launch argument parsing issue was corrected using typed UserDefaults accessors and a regression test. This is correctness evidence, not a paired speed comparison. The previous Dark Moon SimMetalHost limitation remains; its exact outdoor/window route needs phone testing.

The final archive passes identity, privacy, private-data exclusion, strict signatures and **four real matching dSYMs**, including EmuDenWidgets. Both optimized Azahar cores were rebuilt with reproducible patches; source versions and native-save/snapshot formats remain unchanged. Build 17 is installed on the original Duo Simulator with all 107 original Documents files (1,751,582,736 bytes) byte-identical across installation, without launching it. No physical-device install, TestFlight upload or distribution IPA export was performed. Signed builds 14–16 and their source packages remain preserved.

Catalog v6 now provides **40 downloadable scenes and 24 covers**. The latest bounded scheduled pass added SteamWorld Dig, SteamWorld Heist, Bravely Second and Dragon Quest VII. All four were visually inspected and anonymously/offline verified after publication; old image URLs and the public audience remain. The expansion queue has 27 pending and five blocked entries. Image-tool rejections remain blocked, with existing fallbacks.

Remaining device checks: Dark Moon timing/thermals, actual Home Screen widget pinning and links, physical controls/haptics, and live inner-display folding/landscape. Full tester steps are in `en-US/what-to-test.txt`.

---

# Build 16 — full outer display and shader-stall candidate

**EmuDen 0.1.0 (16)** is built, signed and locally validated for internal TestFlight preparation. Player Settings → Duo layout → **Fill display** now expands across the outer display instead of retaining the old centered insets; the inner layout retains its fold regions. Apple async-eligible draws bypass the synchronous driver-cache probe and use the existing background compiler. Required graphics work still waits, and no new Dark Moon phone improvement is claimed.

- Archive: `build/TestFlight/EmuDen-0.1.0-16.xcarchive`.
- Matching source: `build/TestFlight/EmuDen-0.1.0-16-source.tar.gz`.
- Preparation report: `build/TestFlight/Build16-PreparationReport.json`.
- [Implementation and limits](../Docs/BUILD-16.md) · [actual outer-display captures](../Docs/Preview/Build16-README.md).

**45 domain tests and four distinct UI scenarios have passing latest results.** The strengthened outer test checks full app bounds and exact lower-screen touch mapping (80, 180). The inner panel/skin and book checks passed in the first bundle; the final tabletop check verifies an actual A-button event and controller expansion. An earlier AX `isHittable` assertion failed despite a visible button; the actual event passes. A subsequent attempt was cancelled during Simulator launch recovery; the restarted final pair passed. Only the attachment caption changed afterward to describe the actual orientation. Reviewing captures showed the Duo Simulator stayed in portrait after a landscape request: portrait is visually verified; landscape geometry is domain-tested, while live landscape appearance remains pending.

The actual Mario Golf 3× renderer completed 841 frames, saved/restored a state and continued. Both post-restore screens were visually reviewed, including the imported Mii. A roughly 1.14-second required pipeline wait remains after restore. Dark Moon again stopped around frame 540 with local Apple SimMetalHost crash reports; its outdoor/window route cannot be verified in this Simulator. The owner's previous phone reports show mostly 60 FPS in both titles, with the specified Dark Moon hitches even at 1× and Reduce shader pauses on. These are separate from the new candidate's unmeasured phone effect.

The archive passed identity, framework, privacy, private-data exclusion, strict signature and all three real matching dSYM checks. Both optimized Azahar cores were rebuilt; source versions and snapshot formats remain unchanged. Build 16 is installed on the original Duo Simulator with all 107 original Documents files byte-identical across installation. No physical phone installation, TestFlight upload or distribution IPA export was performed. Signed builds 14 and 15 and their matching source remain preserved.

Catalog v4 provides **34 downloadable scene backgrounds and 24 covers**. Four new scenes are publicly published and anonymously/offline verified; previous image URLs are preserved. The icon, audio, Option A scene transition and console/cover fallbacks remain. The scheduled artwork queue still has 35 pending items and three blocked entries.

Remaining checks: exact Dark Moon phone scenes, live landscape and inner-display folding, physical controller/haptics and sustained thermals. No new performance percentage is claimed.

---

# Build 15 — custom artwork without the console flash

**EmuDen 0.1.0 (15)** is built, signed and locally validated for internal TestFlight preparation. Known game backgrounds now load against black and fade in; the console scene is omitted while their image is pending. Already displayed artwork stays visible during same-game refreshes. Unknown games, failed lookups and an explicit Console background preference retain the console fallback. Fast selection changes are guarded against late image completions.

- Archive: `build/TestFlight/EmuDen-0.1.0-15.xcarchive`.
- Matching source: `build/TestFlight/EmuDen-0.1.0-15-source.tar.gz`.
- Preparation report: `build/TestFlight/Build15-PreparationReport.json`.
- [Implementation](../Docs/BUILD-15.md) · [actual transition captures](../Docs/Preview/Build15-README.md).

**44 domain tests and 3 distinct targeted UI scenarios have passing latest results.** The new metadata regression checks availability without downloading, including explicit matches, offline use and catalog changes. A deliberately delayed Simulator load verifies almost-black pixels before the scene appears, followed by the actual artwork. The final preference/matching/reset test and collection/search/shelf scenario also passed. An initial context-menu miss is retained; test gestures now use the tile center with a bounded retry. The first permissive image check was tightened after inspection showed that a dark console image could satisfy it, and the final captures were visually reviewed.

The release archive passed identity, device-framework, privacy, private-data exclusion, signatures and all three real matching dSYM checks. The Simulator-only delay is compiled out for device builds. Build 15 is installed on the original Duo Simulator with its original Documents byte-identical across installation. The physical B Duo was not used. No TestFlight upload or IPA export was performed.

The live catalog and bundled seed remain version 3: **30 downloadable game backgrounds and 24 generated covers**. Four generic console backgrounds and the earlier bundled hero artwork are separate. The public catalog was checked against the bundled seed. Existing scheduled expansion remains configured; this pass generated no new images.

Bridge sources, core frameworks, player/resolution/FPS code, icon, menu audio, touch and save-state formats remain as build 14. Its performance work is retained, with no additional speed claim from this UI fix. Build 14’s signed archive/source remain preserved. Physical-phone visual verification and the previously documented performance/game checks remain pending.

---

# Build 14 — 3DS performance, fullscreen controls and handheld icon

**EmuDen 0.1.0 (14)** is built, signed and locally validated for internal TestFlight preparation. The final archive uses the replacement glass handheld/portal icon, with no lettering. No App Store Connect upload, IPA export or physical-phone installation was performed.

- Archive: `build/TestFlight/EmuDen-0.1.0-14.xcarchive`.
- Matching source: `build/TestFlight/EmuDen-0.1.0-14-source.tar.gz`.
- Preparation report: `build/TestFlight/Build14-PreparationReport.json`.
- [Implementation and limits](../Docs/BUILD-14.md) · [actual player captures](../Docs/Preview/Build14-README.md) · [icon master/exporter](../Docs/Branding/README.md).
- [Live public artwork catalog](https://emuden-artwork-catalog.headyopossum2.chatgpt.site) · [expansion queue/provenance](../Docs/Design/ArtworkCatalog/README.md).

Frame transfers and display-image creation now complete on a worker, with a completion guard for the core’s shared presentation image. The final matched four-run Mario Golf transfer comparison measured **15.07 → 12.005 ms median emulation-thread cost**, about **20.3% less time**, across 26 blocks of 120 frames per mode. This is Mac Simulator evidence, not a phone FPS gain. The paired runs use the final transfer implementation before later header/accessibility and icon polish. Core versions, native-save paths and snapshot formats are unchanged. Save/restore and teardown drain pending transfers.

Settings and Player Settings offer 1×/2×/3× internal resolution, applied when reopening a game. Native 1× remains the fastest default; 2×/3× increase clarity and GPU work. Both higher scales passed real Mario Golf state capture/restore and continued rendering, with actual top/bottom PNG dimensions verified. The title/pause/menu header fades after three seconds and returns on a top-screen tap. Lower-screen controls continue working. Loading, pause, errors and open menus keep the header visible. FPS is optional and off by default; when enabled its corner badge remains after the header fades.

**43 domain tests and seven distinct targeted UI scenarios have passing latest results:** header/FPS/persistence, resolution persistence, controller shell/panels, quick save/load/relaunch/resume, book layout, tabletop expansion and shader preference persistence. The final three-scenario release regression passed after a direct image check exposed residual glass drawing in the earlier removal transition. The toolbar now uses animated opacity; final release captures confirm it disappears visually with FPS on and off. Earlier failed runs remain as evidence. Core/render checks use real Mario Golf; the real emulated UI state test uses licensed Homebrew Menu. Fold fixtures verify geometry rather than physical folding.

The archive passed identity, device-framework, privacy, private-data exclusion, signature and all three real matching dSYM checks. The final simulator build is installed on the original Duo simulator; every original Documents file remained byte-identical across installation. QA saves were restored from their pre-test backup. The separate physical B Duo was not used. The new icon is opaque RGB 1024×1024, with the unchanged generated master and exporter included in source.

Artwork catalog v3 adds Kirby Planet Robobot and Pilotwings Resort: **30 scenes and 24 generated covers**, retaining all 28 previous entries and 52 existing image URLs. The native Swift client verified both new downloads anonymously and reused them offline. The public Site contains only gallery/generated delivery images/title metadata. A 44-title queue has 2 accepted, 3 blocked and 39 pending entries; normal hourly follow-ups continue through 08:00 America/New_York on 2026-11-12, subject to usage and the Mac/app being available. They preserve this signed release snapshot. Unknown or blocked scenes keep existing fallbacks.

Use **Settings → Import Mii file → `errfix.3dsx`**, or a decrypted Mii resource `.app`, then close and reopen the game. `CFL_DB.dat` alone has personal records rather than head models. The verified local installer remains at `build/Downloads/MiiTest/errfix.3dsx` and is excluded from the app, source and public host.

Sustained B Duo FPS/thermals, true inner-display/folding, haptics and the exact Donkey Kong shot remain unverified. Dark Moon’s loading reached an Apple SimMetalHost shader-compilation crash with both asynchronous and synchronous transfers; no walkthrough or phone fix is claimed. Existing audio-session runtime diagnostics remain. Only 3DS is playable. Build 13 and its source/archive are preserved; intermediate build-14 archives are under `build/Build14-Candidates`.

---

# Build 13 — live downloadable artwork collection

**EmuDen 0.1.0 (13)** is built, signed and locally validated for internal TestFlight preparation. The final archive includes the selected-cover scroll correction. No App Store Connect upload, IPA export or physical phone installation was performed.

- Archive: `build/TestFlight/EmuDen-0.1.0-13.xcarchive`.
- Matching complete source: `build/TestFlight/EmuDen-0.1.0-13-source.tar.gz`.
- Preparation report: `build/TestFlight/Build13-PreparationReport.json`.
- [Implementation and limits](../Docs/BUILD-13.md) · [actual simulator previews](../Docs/Preview/Build13-README.md).
- [Live public artwork gallery](https://emuden-artwork-catalog.headyopossum2.chatgpt.site) · [published gallery capture](../Docs/Preview/Build13-Artwork-Published.jpg).
- [Built-in image generation, exact prompts and master paths](../Docs/Design/Build13-Artwork/PROVENANCE.md).

Collection 01 covers the first 25 entries of a pinned historical community top-100 list plus Donkey Kong, Tomodachi Life and Dark Moon. It contains 28 original scenes and 24 new covers. Four covers retain existing fallbacks after generation failures; all four have new scenes. Paired editions/families share entries. The public Site contains generated JPEGs and title/ID metadata only, by the owner's explicit audience choice. App source, ROMs, saves, system archives, signing data and contact details are excluded from that host.

The app automatically matches supported games by retail program ID or exact title aliases, downloads images on demand and caches them offline. User-selected artwork retains priority. A newer validated catalog can update artwork without another app release; damaged or unavailable replacements retain previous successful images. Network requests stop during emulation. The OS can reclaim automatic caches; explicitly chosen images remain in Documents. Unknown scenes keep their bundled console backgrounds. The approved Option A layout and full-search dock hiding remain, and choosing a search result brings its selected cover into view.

43 domain tests and seven distinct targeted UI scenarios passed. Five artwork/navigation scenarios used isolated metadata-only fixtures and verified preseeded images; two real-game scenarios separately checked Mario Golf launch and Homebrew Menu quick save/load/relaunch/resume. The final collection scenario passed again after the new shelf assertion exposed and corrected a view-creation scroll problem. Its earlier failed result and pre-polish archive are preserved. The live Swift catalog client independently downloaded and verified all 52 images anonymously (35,476,617 bytes), accepted a newer index, then reused every image with networking disabled.

The final archive passed identity, privacy, device framework, private-data exclusion, signatures and all three real matching dSYM checks. The app seed matches the published catalog. Core framework UUIDs, Bridge, menu audio and save-state sources remain unchanged from build 12. Preparation evidence and matching-source hashes are recorded in the report. Existing audio-session runtime diagnostics are retained there; no artwork-driven gameplay performance improvement is claimed.

Phone testing, the true inner-display comparison, continuous physical folding, haptics and sustained performance remain pending. Only the 3DS core is playable. Build 12 and its source/archive remain preserved; the first build-13 archive is at `build/Build13-Candidates/Before-Shelf-Polish.xcarchive`.

---

# Build 12 — artwork rollout and search dock fix

**EmuDen 0.1.0 (12)** is built, signed and locally validated for internal TestFlight preparation. The final archive includes the search dock fix. No upload, IPA export or physical phone installation was performed.

- Archive: `build/TestFlight/EmuDen-0.1.0-12.xcarchive`.
- Matching complete source: `build/TestFlight/EmuDen-0.1.0-12-source.tar.gz`.
- Preparation report: `build/TestFlight/Build12-PreparationReport.json`.
- Implementation and limits: [BUILD-12](../Docs/BUILD-12.md).
- Actual simulator captures: [console fallback](../Docs/Preview/Build12-Console-Fallback.png), [search without the dock](../Docs/Preview/Build12-Search-No-Dock.png), [artwork previews](../Docs/Preview/Build12-README.md).
- Built-in image-generation prompts and asset paths: [console artwork](../Docs/Design/Build12-Console-Art/prompts.json).

Games without suitable backgrounds use original bundled console scenes. The 3DS, PSP, PlayStation and GameCube scenes work offline; only 3DS is playable. Standard covers fill the cards, recognized retail scans lose their right-hand case strip, and a pinned 1,289-release-ID table improves identification of renamed games. The artwork editor supports title corrections, chosen covers/backgrounds, a console-background preference and restoring automatic artwork. ROM names, library UUIDs and save identities are preserved. Downloads pause during play.

The Liquid Glass dock hides for the entire search session, including when the keyboard is dismissed, and returns when search closes. Both ordinary and fold-aware layouts use this behavior.

**33 domain checks passed. Seven distinct targeted UI scenarios have passing latest results:** artwork import, matching/preferences/reset, search/opening console, fold fixtures, coming-soon gating, real Mario Golf launch, and Homebrew Menu quick save/load/relaunch/resume. Files import passed on both the Duo iOS 27.1 and separate iPhone iOS 26 simulators. Saved custom PNG dimensions/markers and unchanged fixture games/library were inspected separately. The final search check explicitly covers typing, keyboard submission and closing search.

Earlier failed UI attempts are retained. They exposed short document-service waits, incorrect Files hit targets, one cold-start context-menu failure, and two simulator launch/background-assertion failures. Updated waits/hit targets and the longer long-press passed; the latest fold/search checks also passed. Artwork fixtures contain metadata only and do not establish game compatibility. Real-game regression checks use the owner's separate existing simulator library.

The final archive passed identity, privacy, device frameworks, private-data exclusion, signatures and all three real matching dSYM checks. Bundled artwork/audio/metadata match the working resources. Core framework UUIDs, Bridge sources and save-state formats match build 11. No new phone-performance claim is made.

The shared, independently updated HD art feed remains a later rollout stage. Standard covers download now; custom HD art is bundled or imported locally. Tight portrait crops can still trim wide logos. The live inner-display comparison, continuous physical folding review, phone haptics and sustained phone performance remain pending while the owner is away from the Mac.

Build 11 and its source/archive are preserved. The initial build-12 archive before the search fix is preserved at `build/Build12-Candidates/Before-Search-Dock-Fix.xcarchive`; use the final TestFlight path above.

---

# Build 11 — Option A reference match

**EmuDen 0.1.0 (11)** is built, signed and locally validated for the owner's internal TestFlight preparation. The final live inner-display comparison is deferred until the owner returns to unlock the Mac.

- Archive: `build/TestFlight/EmuDen-0.1.0-11.xcarchive`.
- Complete matching source: `build/TestFlight/EmuDen-0.1.0-11-source.tar.gz`.
- Preparation report: `build/TestFlight/Build11-PreparationReport.json`.
- Changes and verification: [BUILD-11](../Docs/BUILD-11.md).
- Current rendered portrait capture: [Home](../Docs/Preview/Build11-Outer-Home.png).
- Current automated captures: [Search](../Docs/Preview/Build11-Search.png), [Opening console](../Docs/Preview/Build11-Duo-Layout.png).
- Artwork files, built-in image-generation provenance and recorded prompts: [CinematicArt](../Resources/CinematicArt/PROVENANCE.md).

Home now follows the approved A artwork, large cover cards, Play capsule, clear glass dock and circular controls. Settings stays in the dock navigation; pause is a centered floating panel; Duo layout opens across the display. Search, focus, button feedback, original sound cues and the unfolding console remain. The compact Library keeps readable filters and two cover columns; the inner display uses four columns.

26 domain tests and 10 distinct targeted UI scenarios passed, including real Mario Golf launch, Homebrew Menu save/load/relaunch/resume, both fold fixtures, controller layouts, Mii setup, search, future-system gating and preference persistence. The initial three artwork hit-area failures were corrected and passed on rerun. Captured test logs have zero publishing/modifying-state-during-view-update warnings. The final portrait artwork adjustment also passed the focused search/unfolding-console scenario.

The archive passed identity, device framework, privacy, private-data exclusion, signature and all three real matching dSYM checks. The 3DS core and save formats are unchanged from build 10. The nine original sound assets passed their deterministic generator check.

Current portrait screenshots are actual simulator renders, not concept mockups. The last live comparison on the true inner display and continuous pose/motion review remain pending. Phone sound/haptics and game performance require a physical-device retest. This build was prepared locally; upload, IPA export and phone installation were not performed.

Build 10 and its source/archive are preserved. Earlier build-11 candidates are preserved under `build/Build11-Candidates`; the final archive is the TestFlight path above.

---

# Build 10 — Option A / Cinematic Glass

**EmuDen 0.1.0 (10)** is implemented, signed and locally validated for the owner's next internal TestFlight upload. No upload, IPA export or physical phone installation was performed.

- Archive: `build/TestFlight/EmuDen-0.1.0-10.xcarchive`.
- Matching complete source: `build/TestFlight/EmuDen-0.1.0-10-source.tar.gz`.
- Preparation report: `build/TestFlight/Build10-PreparationReport.json`.
- Design and validation details: [BUILD-10](../Docs/BUILD-10.md).
- Actual app captures: [Home](../Docs/Preview/Build10-Console-Home.png), [Search](../Docs/Preview/Build10-Search.png), [Duo model](../Docs/Preview/Build10-Opening-Console.png), [Paused menu](../Docs/Preview/Build10-Game-Menu.png).
- Sound audition: [original cues](../Docs/Preview/Build10-Original-Sounds.wav).

The selected design uses native Liquid Glass navigation, a morphing search control, game-scene previews, restrained spring/crossfade/staged transitions, original chimes and haptics, cinematic settings/Mii/performance/paused menus, and an opening graphite clamshell in Duo layout settings. It retains the build-9 CPU/GPU core and snapshot format. The library never runs emulation to produce its previews.

26 domain tests and 11 distinct UI scenarios passed, including real 3DS launch, save/load/resume, both fold fixtures and controller display modes. Focused checks passed again after final narrow-panel and alert-presentation polish. One conditional Reduce Motion/Reduce Transparency visual check was skipped because those settings were not both enabled. All three exact real dSYMs, identity, manifests, device frameworks, private-data exclusions and signatures passed.

Manual phone sound/haptic and continuous inner-display/fold checks remain. The Mac stayed locked; CLI screenshots and automation worked, while the attempted display video captured Home Screen and was excluded from review previews. This release does not claim a new phone FPS result or resolve the exact earlier GPU crash.

The first build-10 archive is preserved in `build/Build10-UI-Candidates/Before-Compact-Polish.xcarchive`; build 9's sources and artifacts are preserved. The final archive above includes the narrow-fold polish and alert-presentation cleanup.

---

# Build 9 — faster 3DS CPU and clearer setup

**EmuDen 0.1.0 (9)** is locally built, tested and archived for the owner's next internal TestFlight upload. No build-9 upload, IPA export or phone install was performed.

- Archive: `build/TestFlight/EmuDen-0.1.0-9.xcarchive`. Identity, framework slices, privacy manifests, private-data exclusion, signatures and all three exact real dSYMs passed. Preparation report: `build/TestFlight/Build9-PreparationReport.json`.
- Upgraded the pinned core to Azahar 2127.0-rc1 with FastInterp. Both device and simulator use optimized Release binaries, native 1× graphics, the existing game accuracy profiles and no CPU/shader JIT. This is an upstream release candidate. Its GPL-3.0-or-later license and complete matching source are included.
- Matched simulator sequence: **21.78 → 59.98 FPS**, median core/display cost **45.61 → 12.23 ms** across 13 blocks, with shader pauses off in both runs. This uses the Mac, not the phone. Evidence: `build/build9-performance-comparison.json` and `build/Build9-Performance-{Before,After}`.
- Retrieved the owner's actual build-8 phone crash read-only. It is a null-image access in MoltenVK image-barrier submission, not a simple slow-frame or memory-pressure termination. The simulator completed a Donkey Kong normal drive and Power Shot drives with shader pauses off/on, with no null-image detection. The phone enables fragment shader interlock and the simulator does not; **the exact phone crash/perfect-impact case still needs a device retest**. Keep Reduce shader pauses enabled. It defaults on for fresh preferences; existing explicit settings remain.
- Mii setup accepts `.app` or a selected `errfix.3dsx` directly, without running the installer. The real local installer extracted bytes identical to the previously tested archive. Core upgrades back up native data; old snapshots are retained separately. New system imports use a fresh snapshot revision so the old face cannot return through a resume point. No Nintendo resources are bundled.
- Calmer modern home styling, readable labels, a frosted dock, Library entry, grouped Settings and a focused Mii guide are complete. Narrow Duo panels use readable stacked actions. Session logs can be exported explicitly from Settings.
- **25/25 domain tests** and **7/7 Release Duo UI tests** passed (`build/EmuDen-Build9-Final.xcresult`). The final compact-dock follow-up passed (`build/EmuDen-Build9-Duo-Final.xcresult`). An earlier Mii-screen test had an ambiguous Done selector; the final identifiers and test are corrected.
- Matching source: `build/TestFlight/EmuDen-0.1.0-9-source.tar.gz`. The strict allowlist excludes phone crash reports, games, Mii data, saves, downloaded covers, simulator data, contacts and credentials.
- Save using the game's own menu **before updating**. Old quick/resume snapshots cannot be loaded by this engine; files are retained for the older build. New snapshots work with the new engine. First visits may regenerate shaders. Live phone speed, the exact crash, physical haptics/controller feel and live hinge transitions remain device checks. Dark Moon is still unavailable locally.

Open the archive in Xcode Organizer → **Distribute App → TestFlight Internal Only** to sign/export/upload. Apple processing is not performed by local validation.

[Home](../Docs/Preview/Build9-Console-Home.png) · [Settings](../Docs/Preview/Build9-Settings.png) · [Mii setup](../Docs/Preview/Build9-Mii-Setup.png) · [Duo book](../Docs/Preview/Build9-Duo-Book.png) · [Build notes](../Docs/BUILD-9.md).

---

# Build 8 console polish and menu audio

**EmuDen 0.1.0 (8)** is the current local build for internal TestFlight preparation. No build-8 upload, IPA export or physical-phone install was performed.

- Current archive: `build/TestFlight/EmuDen-0.1.0-8.xcarchive`. The archive validator checks identity, device frameworks, manifests, signatures, private-data exclusion and all three matching real dSYMs. The final preparation report is `build/TestFlight/Build8-PreparationReport.json`.
- The console menu adds a compact 3DS/PSP/PS1/GC selector, glass-to-cyan cover focus, a softly lit Start/Continue button and a clearer Console settings sheet. PSP, PS1 and GameCube have individual Coming soon pages, with no launch route. Only 3DS is playable. Controller shoulder buttons switch systems.
- Five original procedurally synthesized glass cues cover browse, confirm, back, launch and coming-soon selection. Console settings has persistent sound mute and volume, plus a preview. The ambient audio category follows Silent Mode; menu players stop before gameplay and while inactive. No third-party samples or game melodies are used. Audio PCM, formats, bundled presence, unclipped peaks, DC offset and zero-ended fades are checked in `build/build8-menu-audio-report.json` and the deterministic generator check.
- **6/6 Release Duo UI tests passed**, 0 failures: `build/EmuDen-Build8-Final.xcresult`. These cover the real Mario Golf shelf/search/collection/launch/return path, both fold fixtures, Mii setup, persistent sound mute and preview availability, future-system gating, and Quick Save/Load/relaunch/resume. **3/3 focused layout/settings checks passed** after visual refinements in `build/EmuDen-Build8-Layout.xcresult`; future return buttons are fully above the dock. The final home launch/return check also passed (**1/1**) in `build/EmuDen-Build8-Home-Final.xcresult`.
- Source package: `build/TestFlight/EmuDen-0.1.0-8-source.tar.gz`, using the strict allowlist. Original sound assets, generator, notice and UI sources are included; games, Mii resources, saves, downloaded covers, private contacts and signing credentials are excluded.
- Previews are `Docs/Preview/Build8-*.png`; listen to `build/EmuDen-Menu-Sound-Preview.wav` for focus/confirm/back/launch/coming-soon cues. Earlier build-8 visual candidates are retained under `build/Build8-UI-Candidates`; build 7 and older released preparation artifacts remain preserved.
- No core or graphics/performance settings changed. Physical speaker balance, Silent Mode behavior, controller feel, haptics and live hinge transitions still need a phone check. Dark Moon remains unavailable locally because of the owner's iCloud upload error; no new FPS claim is made.

Open the current archive in Xcode Organizer → **Distribute App → TestFlight Internal Only** for distribution signing and upload. Preparation and local validation do not perform the upload or Apple processing.

[Home](../Docs/Preview/Build8-Console-Home.png) · [PSP](../Docs/Preview/Build8-PSP-Coming-Soon.png) · [Sound settings](../Docs/Preview/Build8-Menu-Sound.png) · [Build notes](../Docs/BUILD-8.md).

---

# Build 7 console home — validated

**EmuDen 0.1.0 (7)** is built, installed in the dedicated Duo simulator and archived for the next internal TestFlight upload. No build-7 upload, IPA export or physical-phone install was performed.

- Current archive: `build/TestFlight/EmuDen-0.1.0-7.xcarchive`. Archive identity, Release device frameworks, privacy manifests, private-data exclusion, signatures and all three matching real dSYMs passed.
- The home screen now has a native animated blue-wave backdrop, a snapping focused cover shelf, selected-game details, a Collection grid, search, haptic selection and a quick-action dock. Gamepad selection/start/back/settings and mapped button glyphs are wired. Reduced Motion keeps the background static; menu animation stops while playing, inactive or presenting setup/import.
- Duo fold regions separate game details from browsing/actions. Narrow panels use icon tabs, compact controls and the selected cover as the launch target when space is short. Pose fixtures are diagnostic, not a live physical hinge test.
- **All 4 Release Duo UI tests passed** in `build/EmuDen-Build7-Console4.xcresult`: home shelf/search/collection and Mario Golf launch/return; both fold fixtures with usable controls; library/Mii setup; and Quick Save/Load/close/relaunch/resume. Earlier reports retain the narrow-layout and test-timing failures. The final checks handle saved resume prompts and wait for actual game pixels after startup fades.
- No emulator-core or performance settings changed. Azahar and MoltenVK UUIDs match build 6. Existing physical FPS/compatibility limits remain; menu controller feel, haptics and live hinge transitions still require phone testing.
- Source package: `build/TestFlight/EmuDen-0.1.0-7-source.tar.gz`, with the strict allowlist excluding games, downloaded Nintendo resources, saves, simulator data, private contacts and signing credentials.
- Previews: `Docs/Preview/Build7-Console-Home.png`, `Build7-Game-Shelf.png`, `Build7-Duo-Tabletop.png`, `Build7-Duo-Book.png`. Current simulator game files and covers are preserved; earlier build-6 artifacts remain intact.

Open the archive in Xcode Organizer → **Distribute App → TestFlight Internal Only** to perform distribution signing and upload. The agent has not uploaded it.

[Home preview](../Docs/Preview/Build7-Console-Home.png) · [Duo tabletop](../Docs/Preview/Build7-Duo-Tabletop.png) · [Duo book](../Docs/Preview/Build7-Duo-Book.png) · [Build notes](../Docs/BUILD-7.md).

---

# Build 6 local validation

**EmuDen 0.1.0 (6)** is built, archived and locally validated for the next internal TestFlight upload. No build-6 upload, distribution IPA export or physical-phone install was performed by the agent.

- Current archive: `build/TestFlight/EmuDen-0.1.0-6.xcarchive`. Release device frameworks, privacy manifests, private-data exclusion, strict signatures and all three matching real dSYMs passed. The earlier build-6 archive and prior build-5/4 artifacts are preserved.
- At the owner's request, the Mii package was downloaded and run in an isolated simulator app. Mario Golf's selected Mii rendered with a normal head, face and hair, before and after Quick Load.
- The extracted 1,106,432-byte Mii archive also passed the actual importer and a separate canonical-app test with **no other Nintendo system archives installed**. Asynchronous shaders were enabled, the Mii rendered normally, and a state round trip continued for 120 further frames (1,261 total). See `build/MiiTest/result.json`, `build/MiiTest/Standalone` and `Docs/Preview/Build6-Standalone-Mii.png`.
- The downloadable/importable test file is `build/MiiTest/downloaded-mii.app`. It is excluded from the app/source packages. After importing, reopen the game and choose **Start normally**; older resume/quick states may retain the old Mii appearance.
- New **Player settings → Reduce shader pauses** exposes the core's existing background compilation. It defaults off; enabling it can make new objects appear briefly late. The shader-profile restoration fix eliminates the cache regeneration reproduced after Quick Load. CPU/shader JIT, native resolution, CPU clock and multiplication accuracy are unchanged.
- Real Mario Golf and Ocarina Rev 1 covers downloaded, were cached and displayed in the simulator library. The Libretro artwork server resolves shared revision covers; matching is local. The index contains 2,148 3DS cover names. Long-press a game → **Find game artwork** retries. See `build/build6-artwork-validation.json` and `Docs/Preview/Build6-Game-Artwork.png`.
- **21 domain tests passed.** The library/Mii setup and Quick Save/Load/relaunch/resume UI tests passed in `build/EmuDen-Build6-Validation.xcresult`. The new shader preference/persistence test passed in `build/EmuDen-Build6-Shader-Preference.xcresult` after correcting its tap from the whole Form row to the switch control. The first report retains that initial test failure for traceability.
- Matching source package: `build/TestFlight/EmuDen-0.1.0-6-source.tar.gz`, generated with the strict allowlist. Games, downloaded Nintendo resources, private contacts, saves and simulator data are excluded.
- **Dark Moon's exact freezing scene remains unverified:** the owner confirmed its iCloud upload failed, so a complete copy is not available on the Mac. No physical FPS percentage or full-speed claim is made. AirDrop to the Mac can bypass that iCloud failure for a future scene comparison. Detective Pikachu also remains unverified without a complete local copy.

Open the current archive in Xcode Organizer → **Distribute App → TestFlight Internal Only**. Distribution signing, upload and Apple processing happen in that flow; a build-6 signed IPA has not been exported.

[Build 6 notes](../Docs/BUILD-6.md) · [Artwork preview](../Docs/Preview/Build6-Game-Artwork.png) · [Imported Mii preview](../Docs/Preview/Build6-Standalone-Mii.png).

---

# Build 5 local validation

**EmuDen 0.1.0 (5)** is built and archived for internal TestFlight distribution. No build 5 upload or physical-phone install was performed. The earlier build 4 IPA/source and owner's uploaded build 3 remain preserved.

- Archive: `build/TestFlight/EmuDen-0.1.0-5.xcarchive`. Archive identity, Release device frameworks, privacy manifests, private-data exclusion and strict signatures passed. The app, Azahar and MoltenVK all have real matching dSYMs.
- Sixteen domain checks passed, including separate quick/resume state integrity, invalid imports, data preservation and full-panel fold geometry. The C++ input latch self-check passed.
- Duo simulator results: `build/EmuDen-Build5-Validation2.xcresult` passed all 4 tests: Quick Save/Load plus close/relaunch/resume, controller shell/full-panel settings, Mii setup, and 600-frame Mario Golf startup. Earlier button-tap and controller-expansion UI regressions passed after the UIKit input change.
- A first state-restore regression exposed the recreated renderer's missing shader cache. The source fix was rebuilt for both architectures and the full restore/reopen test now passes. A pre-test Simulator Mach -308 launch failure was followed by the successful run above.
- Direct gameplay checks passed in the second emulator Duo after the automated iOS 27.1 runner aborted while preparing tests. Each direct run delivered 1,321 frames, captured/restored a quick state, then continued rendering for at least 120 frames. Captures show Forest Course loading and a touch-selected Mii character with a generic three-dimensional head visible from an angle. These are Mac/simulator results, not a physical FPS comparison.
- The final software-shader optimization passed 400,000 reference operations and AddressSanitizer/UndefinedBehaviorSanitizer. Optimized binary inspection shows three `operator new` sites removed from the interpreter. Both cores were rebuilt and the final archive revalidated; earlier local build-5 archives are preserved with descriptive backup names.
- Detective Pikachu's complete game file is unavailable locally; its saving hang is unverified. The incomplete transfer is excluded from test games. Authentic Mii rendering requires the owner's console archive. Physical haptics, gamepad hardware and thermal behavior require device tests.
- Matching source package: `build/TestFlight/EmuDen-0.1.0-5-source.tar.gz`; strict allowlist validation excludes games, console data and private contacts.
- A build 5 distribution IPA has not been exported. Use the archive in Xcode Organizer for **TestFlight Internal Only**, which signs for distribution and includes framework symbols. Apple processing/export compliance are not independently verified.

[Gameplay implementation and limits](../Docs/BUILD-5.md) · [Console skin preview](../Docs/Preview/Build5-Console-Skin.png) · [Full panels preview](../Docs/Preview/Build5-Full-Panels.png).

## Preserved build 4 preparation

### Build 4 correction and earlier handoff

**Build 4 correction:** EmuDen 0.1.0 (4), for internal TestFlight only. Build 3 was uploaded successfully by the owner; Xcode reported missing framework dSYMs, as shown in the supplied screenshot and Organizer's Uploaded to Apple status.

- The build-4 Release archive passed: `build/TestFlight/EmuDen-0.1.0-4.xcarchive`.
- Its app, Azahar framework and MoltenVK framework all have nonempty DWARF/line information with UUIDs matching their exact archived binaries.
- Negative regression checks reject both missing symbols in build 3 and a real dSYM belonging to the wrong binary. The rebuilt MoltenVK retains all 515 previously exported Vulkan/MoltenVK entry points.
- SDK/source builds remain Release builds; no emulator settings were changed. The original build-3 archive is preserved.
- The signed build-4 IPA was exported to `build/TestFlight/EmuDen-0.1.0-4-Internal/EmuDen.ipa`. The local validator passed distribution signing, Store provisioning, internal-only entitlements and all three matching dSYMs. No build-4 upload was performed. See [the symbol notes](../Docs/DEBUG-SYMBOLS.md).

## Previous build 3 preparation and upload

- Release archive succeeded: `build/TestFlight/EmuDen-0.1.0-3.xcarchive`.
- Local validation passed: identity/build, iPhone+iPad support, opaque 1024px icon, metadata field limits, app/framework privacy manifests, arm64 iOS cores, licensed homebrew demo, exclusion of private contacts/commercial ROMs, and deep/strict code signatures.
- Matching source package generated and checked: `build/TestFlight/EmuDen-0.1.0-3-source.tar.gz`.
- Distribution-signed IPA exported through the signed-in Xcode GUI: `build/TestFlight/EmuDen-0.1.0-3-Internal/EmuDen.ipa`.
- Cloud Managed Apple Distribution certificate and explicit Store profile `iOS Team Store Provisioning Profile: com.brandonaleman.Emulator` were used. Deep/strict signature verification passed. `get-task-allow=false`, `beta-reports-active=true`, and `TFInternalTestingOnly=true` are verified in the exported app.
- Xcode created the live App Store Connect app record: **EmuDen**, bundle ID `com.brandonaleman.Emulator`, SKU `EMUDEN-IOS-001`, primary language English (United States). The name was accepted in that flow.
- Two Release UI regressions passed after branding/privacy changes: library/system setup and actual GPU homebrew boot/close/reopen (`build/EmuDen-Branding.xcresult`).
- Feedback and optional future review contacts are filled in `Private/Contact.json`.
- Public support/privacy URLs and screenshots are deferred for internal-only testing. Draft policy/support text is ready for later hosting.

**Build 3 upload:** Completed by the owner, as confirmed by Xcode Organizer. Apple processing, encryption-question completion and assigning internal testers have not been independently verified. Beta description, What to Test and feedback contact are prepared locally; they have not been entered into the live TestFlight fields.

The earlier CLI export failed with account/certificate/profile lookup errors (`build/TestFlight/export.log`). After the owner unlocked the Mac, the existing signed-in Xcode GUI account successfully created the app record, managed Store signing and exported the IPA. The browser remains at Apple's sign-in screen; this does not prevent uploading the signed IPA through the owner's normal Apple upload flow.

For the corrected symbol upload, use the **build-4 archive** in Xcode Organizer with **TestFlight Internal Only** so Xcode includes the matching framework symbols. The owner uploaded build 3; the agent has not uploaded any build.
