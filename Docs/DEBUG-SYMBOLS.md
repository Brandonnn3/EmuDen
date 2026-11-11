# Framework symbols — build 4

The owner's Xcode screenshot shows that build 3 uploaded successfully, with symbol-upload warnings for these binaries:

- Azahar: `594B3570-02C2-3114-AB38-559E586A894F`
- MoltenVK: `9E86D6B4-FEF6-32C4-9B16-7596894C719F`

The app's own dSYM was present; the two manually embedded libraries lacked dSYMs. The Azahar core was built with `-O3 -DNDEBUG` and no debug information. The official MoltenVK 1.4.2 release disables debug-symbol generation in Release configuration and does not include dSYMs. No matching local symbol bundles were found for the reported UUIDs.

These warnings do not mean the upload failed. They limit crash symbolication for the two frameworks. Apple processing, encryption compliance and tester assignment are separate from these warnings.

## Corrected pipeline

Azahar retains Release optimization and adds line-table debug information, then generates a real dSYM using `dsymutil`. MoltenVK is built from the pinned 1.4.2 source commit with its pinned dependencies, Release configuration, public Metal APIs and DWARF-with-dSYM enabled.

The embed script verifies both dSYMs against their exact binaries, then copies them into Xcode's dSYM output folder during archiving. The archive validator also requires matching UUIDs and nonempty DWARF information/line sections for the app and both frameworks. It correctly rejects build 3's missing framework symbols. Empty dSYM placeholders or edited UUIDs are not used.

The rebuilt libraries have new UUIDs, so this correction requires a new app build. Build 3 and its original archive remain preserved. Its absent debug data cannot be recovered by simply generating symbols for different rebuilt binaries.

```sh
CORE_PCH=ON Scripts/build-simulator-core.sh device
Scripts/build-moltenvk-device.sh
Scripts/archive-testflight.sh
```

The replacement is version 0.1.0, build 4, still for internal testing only. Its final packaging/upload state is recorded in [the TestFlight status](../TestFlight/STATUS.md).

Apple references: [building with debug information](https://developer.apple.com/documentation/xcode/building-your-app-to-include-debugging-information), [matching missing symbols by UUID](https://developer.apple.com/documentation/xcode/locating-a-missing-debug-symbol-file).
