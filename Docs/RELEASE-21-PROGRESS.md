# 3DS-only release candidate, build 21

Isolated SSD worktree: /Volumes/SamsungT7/EmuDenRelease3DS, branch release-3ds-build21, based on preserved build19 commit317a2eab70a2912b5b6ae483a45f66ba35bd1b45. Main EmulatorApp PS1/GameCube app/bridge work stays separate and unfinished. No binary has been uploaded or submitted.

## Current status — November12, final preparation

Completed: local-only original/personal artwork; character-gallery/cover download integration removed, including old automatic-cache display and widgets. All generated masters/public artwork URLs preserved outside this candidate. Original icon/audio retained. Both3DS cores rebuilt with a mandatory patch removing built-in key data and fallback HTTP client certificate/key. The complete public build input replaces those three unused headers with notice-only placeholders; all other pinned upstream source/license files are retained, with recorded original/derived hashes. All local patches reproduce the changed source from that exact input.

Validation:70 domain tests (one private-resource test skipped),3 tooling tests,84 preserved component notices. Final native tests pass for local-artwork/legacy-online preference, all84 offline notices with full selectable GPL text, custom/console reset persistence and full-display controller sizing/touch in portrait+landscape. With the new no-default-data core, actual Mario Golf and Ocarina startup, bundled homebrew/age gate and save-history earlier-point/relaunch/resume tests pass. No phone performance or broad retail compatibility is claimed.

Imported widget-route check is explicitly skipped after verifying that an unavailable regional Apple age service fails closed and removes the indefinite launch spinner. Regional service behavior and actual Home Screen links need signed-device validation. No age bypass was added. Three domain tests cover the eligibility deadline, cancellation and late replies.

Final development-signed archive: build/TestFlight/EmuDen-0.1.0-21.xcarchive. All four genuine matching dSYMs, profiles, capabilities, privacy manifests, original-asset hashes, no-artwork-endpoint checks and no-default-payload scans pass. Pre-policy/earlier21 passes are preserved under build/Preparation21 and must not be distributed. Protected19 archive/source and all143 build18/art records remain unchanged.

Remaining: freeze/publish/verify exact21 source package, publish version-aware support/privacy/source site update (public audience unchanged). App Store export/live forms require Mac/Xcode access: IOConsoleLocked=Yes; prior export reports No Accounts, missing iOS Distribution identity and stale Store profile missing Associated Domains/Declared Age Range. Qualified GPL/Apple distribution-term and relevant name/presentation review remain unresolved; see Docs/Legal/RELEASE-21-REVIEW.md. PublicReleaseCleared remains false. Do not upload/submit or accept legal agreements.

No core, archive or UI build is active at this checkpoint. The last xcodebuild session may be completing teardown; inspect processes before another build. Only the owned Lifecycle QA Simulator (67BA1399-D60F-47DF-9F1C-E8892E808202) was used; never B Duo.

The following history records intermediate failures/corrections; the current status above supersedes earlier pending/unchanged-core statements.

## 13:04 EST checkpoint

Final archive compiles/signs and validates all four genuine matching dSYMs, App Group/associated-domain/age entitlements and device profiles. Resource hash/binary scan passes (11 original assets; neither artwork endpoint in the app executable). Main core/framework hashes match original build19 inputs. Public export attempted without uploading: No Accounts; no local iOS Distribution certificate; cached Store app profile lacks Associated Domains and Declared Age Range. This requires Xcode account/profile access; no signing workaround used.

Native local-artwork/legacy-online-preference UI case passed. Six-case regression batch is active in build/Release21-Regression.xcresult and build/regression-ui.log (xcodebuild PID61634 at this checkpoint); do not launch another UI batch until it ends. First reset assertion failed without awaiting the asynchronous reset; a later disk check showed the preference correctly reset. The revised test waits for the UI value; its rerun is still required. Controller sizing/touch assertions passed but its landscape cleanup scrolling helper failed; return to portrait before cleanup, retaining both orientation assertions. Rerun those two cases after rebuilding the test runner. Other batch results remain pending.

67 domain tests passed, with one local private-resource integration test intentionally skipped. Two tooling tests pass. First source draft preserved at build/Preparation21/FirstPass-EmuDen-21-source.tar.gz; finalize/repackage after checkpoint/test metadata freeze. No source21 or binary21 published yet. Support site's version-aware policy edits pass 14 route/asset checks locally; publication pending, existing public audience unchanged.

The six-case batch was interrupted after a rendered-homebrew pixel assertion timed out and the Quick Look title assertion failed. Do not call those cases passed. Core startup logs show successful Vulkan device creation and program loading, not a verified displayed homebrew frame. The Mac is locked; whether that explains rendering/preview behavior is unproven. Investigate the exported failure captures; defer further duplicate pixel cases until the condition is understood. The underlying core/framework hashes remain unchanged.

Failure-capture diagnosis: the homebrew pixel timeout was a test-fixture resume prompt from November11, visible in the recorded video. The test had not chosen Resume/Start normally, so emulation was correctly paused. This is not evidence of a renderer failure or a Mac-lock effect. The age/demo test now explicitly chooses Start normally if the existing QA resume dialog appears. No owner saves were deleted. Rerun that specific case after rebuilding the runner.

Targeted rerun results: local artwork reset/persistence and full-display controller portrait+landscape sizing/touch mapping both pass (108.38 seconds total). The cleanup action now returns to portrait; the full landscape assertions remain. Replacing the system Quick Look notice preview with an in-app selectable UIKit text view addresses the unverified external-preview path; its new native test is pending. Core executable/bridge unchanged. Current final archive and test runner rebuild are running from current source; inspect their logs before starting the final targeted batch.

## Core packaging audit correction

Both existing CMake caches had ENABLE_BUILTIN_KEYBLOB=ON. Pinned upstream also embeds fallback HTTP client certificate/key arrays. Thus the earlier blanket “no console keys bundled” copy was inaccurate. The release is not cleared and must not use any pre-policy archive/source draft. A mandatory two-file patch now returns no built-in key data, removes the payload includes, and requires user-provided HTTP certificate resources rather than falling back. It is in Scripts/azahar-no-bundled-resources.patch and the release patch runner. Original files/old binaries/archives remain preserved.

The shared root Vendor/Azahar/Source (symlinked into this candidate) has the two C++ changes applied, with originals in build/Preparation21/CoreBeforeResourcePolicy. Main app/bridge/PS1/GameCube source edits were untouched. Incremental root build/AzaharDevice and AzaharSimulator builds were launched from their existing caches; each has only two object recompiles plus core archive/shared-library links. Output logs are in this candidate's build/core-{device,simulator}-resource-policy.log. Do not start duplicate core builds. The CMake flag remains ON in these incremental caches, but the forced source policy removes both include and runtime fallback regardless of the flag; fresh reproducible build source will contain no payload data. Binary payload-absence checks are required before copying new cores.

The exact public source delivery will replace the three unused upstream data headers with notice-only placeholders in a derived archive, preserving every other upstream file and recording original/derived hashes. Do not publish the unmodified upstream payload again in build21. Existing original archive and all earlier releases remain preserved. Validate GPL corresponding source/build completeness from the sanitized input plus patches.

Baseline (pre-resource-policy) native age/demo boot and save-history round trip pass. The first all-notices text view still caused a heavy accessibility snapshot timeout, so it now lists all84 preserved component notices and opens one selectable text at a time. Its final native check remains pending.

## Current verification after resource policy

Both new cores are built and their actual full payloads were compared privately: each of the three arrays is present in the preserved original device binary and absent in both rebuilt binaries. Genuine dSYMs regenerated. CORE-RESOURCE-POLICY-21.json records digests only, never payload bytes. The derived upstream archive passes its header-placeholder/hash checks, and the mandatory patch applies to its exact two source files.

Imported widget route testing exposed an unresponsive Apple regional eligibility request in unsigned Simulator. A15-second cancellable eligibility wrapper now fails closed with the existing error instead of leaving Starting your game stuck. Three new domain tests cover actual results, unresponsive/late replies and cancellation; total70 domain tests pass (one private-resource test skipped). Regional signed-device validation remains required. No age bypass/test override added.

Final current-source test runner is building (build/simulator-build.log); next native batch should cover offline component notices, new-core homebrew/save history, local Mario Golf/Ocarina startup and the regional-service-unavailable path. Previous baseline-core age/demo and save-history checks passed; do not count them as new-core evidence.

Final notices correction: delimiter-like lines inside upstream licenses made the plain-text parser report87 entries. The generator now emits a structured JSON companion with exactly84 preserved sources/texts; a tooling check reconstructs the full original notice bundle byte-for-byte. The final two-case native batch passes for the actual84-file viewer/full GPL text and the legacy online-preference/local-only policy. The final archive includes identical structured/plain notice resources.
