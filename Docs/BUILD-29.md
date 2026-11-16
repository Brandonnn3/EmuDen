# EmuDen0.1.0 build29 — framework metadata correction

Build28's GameCube framework was built for iOS18, but the CMake framework plist
omitted MinimumOSVersion and left bundle name/version fields empty. Apple
rejected the owner's28 upload. Our earlier local validator did not check these
fields.29 supplies an iOS-specific template through MACOSX_FRAMEWORK_INFO_PLIST
and checks every embedded framework against its actual Mach-O platform/minimum
OS, required name and version fields. GameCube declares18.0, the correct device/
Simulator platform, EmuDenGameCube, bundle version1 and short version0.1.0.

No gameplay source or normalized GameCube executable bytes changed. The fixed
bundle copies retain28's genuine UUIDs/dSYMs and full pinned clean build/source/
resource-screening evidence. No full core rebuild is needed for a plist-only
change; future full CMake builds use the corrected template and checker. The
original28 archive/source package/frameworks remain untouched.29 has its own
signed archive and exact corresponding-source package; never overwrite28.

All three emulators and28's format/feature limits remain. See BUILD-28.md.
GameCube accepts validated MEM1 DOL and complete uncompressed GameCube ISO/GCM;
RVZ/Wii/ELF/compressed formats remain unsupported. Retained native evidence is
explicitly identified as28 evidence, with relevant new29 load/switch checks.
Phone speed, retail compatibility/card-save allocation, physical gyro/fold,
regional services/widgets and legal/Apple acceptance remain unclaimed.

The source package retains complete pinned sanitized dependencies and148 notices.
No JIT/private brokers/firmware or default artwork provider is added. No upload,
public release, agreements, spending, owner-phone operations, site/artwork changes
or automation restart are authorized. Public release remains held.

Primary references: Apple MinimumOSVersion and TN2435; CMake3.31
MACOSX_FRAMEWORK_INFO_PLIST. Local checker tests cover missing/empty versions,
wrong platform and deployment mismatch, including the exact rejected28 bundle.
