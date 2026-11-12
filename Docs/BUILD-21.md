# EmuDen 0.1.0 build 21 — 3DS-only local-artwork candidate

Based on preserved build19, in a separate worktree. The Azahar core keeps its pinned version, performance options and save format, with the mandatory resource-policy patch removing built-in key data and the default HTTP client certificate/key. MoltenVK and the emulator bridge remain unchanged. Native saves and snapshot payloads are preserved. PS1/GameCube work stays in the original development tree and is not bundled or advertised as playable here.

The app now uses original console backgrounds, original geometric cover fallbacks and explicit personal image imports. Bundled character/concept art, catalog seed, online download controls and the compiled remote artwork service are removed. Old automatic caches are preserved but ignored; legacy explicit custom imports remain readable. New gameplay captures and WidgetKit images have separate storage paths. Generated masters and prior public artwork URLs remain preserved outside this candidate.

Build number21 distinguishes the public-preparation branch from the unfinished build20 emulator integration. Privacy metadata/store copy and source packaging are updated for the local-artwork behavior. Free United States-only manual-release plan retained. No tip product is made live by this work.

Validation evidence and exact remaining actions: Docs/RELEASE-21-PROGRESS.md. Asset provenance: Docs/Legal/ASSET-REGISTER-21.json. Unresolved distribution/name/live store decisions: Docs/Legal/RELEASE-21-REVIEW.md. Engineering checks do not constitute Apple acceptance or legal clearance.

The deeper audit found that the upstream defaults had been enabled in earlier build caches, contrary to the old store wording. New device/Simulator binaries are rebuilt; all three identified payload arrays are absent and matching dSYMs are checked. The derived source input replaces those unused headers with notice-only placeholders and preserves every other pinned upstream file. See Docs/Legal/CORE-RESOURCE-POLICY-21.json and SANITIZED-UPSTREAM-21.json. Earlier archives/source packages remain preserved; do not use a pre-policy21 archive.

Open-source notices now use an offline component list and selectable native text, so reading a license does not require Quick Look or laying out the entire combined notice file at once.

Final focused verification:70 domain tests (one private-resource skip),3 tooling tests; new-core Mario Golf/Ocarina startup and homebrew/save-history pass in owned Simulator. Local artwork, reset, controller sizing/touch and all84 structured offline notices have native UI coverage. Imported widget play is blocked/skipped by the unavailable Simulator regional service; the error path now fails closed within15 seconds. Final signed archive/manifests/profiles/four real dSYMs and asset/payload scans pass. Phone/regional service and public distribution signing remain pending.
