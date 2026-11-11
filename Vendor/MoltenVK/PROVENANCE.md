MoltenVK 1.4.2 from the official KhronosGroup release.
https://github.com/KhronosGroup/MoltenVK/releases/tag/v1.4.2
Archive SHA256: 562a15a29bc358446a56a4091c5f7e08f604184187c1d34f712148b61ef17276
Apache-2.0 license; see bundled upstream license notices.

Build 4 uses a local iOS Release framework rebuilt from the same official v1.4.2 source commit `db66022459ffb663aa2b50f6b018bc2e124f5edf`, with its upstream-pinned dependency revisions. Scripts/build-moltenvk-device.sh enables real DWARF/dSYM output without selecting Debug configuration and explicitly disables private Metal APIs. The local device framework and matching symbols are staged in Vendor/MoltenVK/Device. The checksum-pinned official SDK remains the header and simulator source.
