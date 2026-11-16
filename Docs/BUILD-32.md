# Build32 — Godzilla rendering compatibility profile

Owner reports Godzilla (Dolphin-format CISO) loads but freezes after Start and
runs slowly. Start is therefore not treated as a missing-controller event.
Sonic Riders (ISO) reportedly runs smoothly. Different titles do not establish
an ISO/CISO cause. No owner game, save or phone was opened or downloaded.

The pinned Dolphin GZD.ini requires EFBEmulateFormatChanges=True; the default
is false. Prior EmuDen bundles omit Sys/GameSettings, so the upstream per-title
profile was not available.32 ships only this exact upstream profile. Before
native boot, the bridge creates GameSettings/GZD.ini in the isolated game user
directory if absent. Dolphin's existing local game-config loader matches the
three-letter GZD ID and applies it. Existing profiles are preserved. Directory
or copy failures produce a startup error instead of silently omitting the
profile. No other title profile, cheat, widescreen patch, firmware or key is
bundled. New-game/restored-game behavior has not been run locally.

This corrects a known missing compatibility setting; it does not establish the
cause of the freeze or prove a fix, speedup or retail compatibility. Enabling
accurate format changes can cost GPU work. Inherited interpreter/native Metal,
3DS/PS1 behavior, import formats, snapshots, native cards and controller routing
remain. No speculative Start remapping or global speed/accuracy hacks.

No new gameplay tests under the owner's prior instruction to add and archive
without them. Only build, signing and corresponding-source/package guards are
run. The GameCube executable and both matching core dSYMs remain identical to
preserved31/29. All earlier signed archives and source packages are preserved.
No export retry, upload, public submission, automation, artwork change, JIT,
proprietary download or owner-data access. Public release remains held.

Source: https://github.com/dolphin-emu/dolphin/blob/f84df02055ab9610feec48e65648cac5a3c098fa/Data/Sys/GameSettings/GZD.ini
Profile SHA256: 5207e848500eedfda01aa435b76d34d29fcefbe834366814166d3ff42a09ba89
