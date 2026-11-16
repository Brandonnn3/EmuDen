# EmuDen0.1.0 build30 — GameCube CISO import

Adds .ciso to the GameCube importer, saved-library schema validation and file
retention. The existing pinned Dolphin CISOBlob backend already reads the format;
no core rebuild or new dependency/firmware/cryptography/JIT is introduced.
A bounded sparse reader validates the CISO header/block map, physical data bounds
and logical GameCube boot metadata using the existing disc/DOL checks. Imports
retain CISO files directly, without expanding them into an ISO. Only the library
importer changes runtime source; existing saves/core generation remain intact.

Supports Dolphin-format GameCube CISO; PSP CSO/CISO, Wii discs, RVZ and arbitrary
archives remain unsupported.29's framework MinimumOSVersion18.0, platform/name/
version correction is preserved. All three emulators and prior features remain.

Owner explicitly requested adding/archive without new gameplay verification.
No CISO gameplay or new regression tests were run; do not imply otherwise.
Normal compilation/signing/package guards still apply. Actual phone speed,
retail compatibility and previous motion/fold limits remain unclaimed. Use the
source/checkpoints for29 and28 for inherited historical evidence only.

No binary upload/public release, account/certificate creation, third-party
contact, agreements, spending, public artwork/site change or automation restart
is authorized. No owner phone/game/save is used. Public release remains held.

Primary format source: pinned Dolphin revisionf84df02055ab9610feec48e65648cac5a3c098fa,
Source/Core/DiscIO/CISOBlob.h and CISOBlob.cpp. The original 32KiB map format is
not PSP CSO, despite its similar magic. Compression support alone does not
establish game compatibility or performance.
