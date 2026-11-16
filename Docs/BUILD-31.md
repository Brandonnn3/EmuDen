# Build31 — CISO import compatibility and useful errors

Owner reports30 rejects an885MB GameCube CISO with the generic invalid-image
message. Screenshots identify the importer stage but do not expose the failing
header check; the specific cause cannot be determined from them. No commercial
ROM was downloaded, requested, opened or tested and no owner phone was used.

Corrects known mismatches with the pinned Dolphin reader: allow trailing CISO
padding while retaining per-read physical bounds; reject actual Wii magic rather
than requiring the otherwise reserved header word to be zero; disc boot uses
the apploader's load table, so do not impose standalone DOL memory/entry rules
on a disc image. Standalone .dol import retains those strict checks. GameCube
magic, identifier, filesystem/apploader and memory/read-size bounds remain.
Precise local rejection reasons now identify header, block-size/map, incomplete
file/provider read, disc type, filesystem or apploader failure instead of the
single generic alert. No diagnostics are uploaded or stored as telemetry.

These are compatibility fixes, not a claim to have reproduced the owner's file
or established that it will boot. Prior no-new-gameplay-verification instruction
is preserved. CISO and the specific game remain unverified. Existing test-source
expectations are updated for apploader-based discs, but no new tests are run.
All other runtime source and core/framework dependencies remain unchanged.
29 metadata fix, source/resource/privacy/age/artwork safeguards remain. No CPU
JIT, firmware, proprietary download, physical-phone use, public publication or
automation restart. Public release held; no upload authorized.

Primary reference: Dolphin f84df02055ab9610feec48e65648cac5a3c098fa,
DiscIO/CISOBlob.cpp (mapped-block reads ignore trailing bytes) and
Core/Boot/Boot_BS2Emu.cpp RunApploader (disc loading follows the apploader table).
