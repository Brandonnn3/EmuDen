# Build22 — legal-remediation candidate

This isolated 3DS-only branch is based on frozen21. There are no emulator/UI/design features added. Version22 separates the changed legal build inputs from the preserved signed/source21 artifacts. Nothing22 is uploaded, submitted, distribution-signed or legally cleared.

Changes: the bundled legacy OpenSSL/SSLeay-licensed LibreSSL implementation is replaced by pinned OpenSSL3.5.9 (Apache2.0). Full offline notices add its license, FAAD2's original attribution/license header, and exact fallback-resource/font credits and terms. Independent replacement-resource generators and GNUUnifont font source are included as separate pinned corresponding-source inputs. The app still omits the character gallery, remote cover services, old automatic artwork display and the known console key/certificate defaults. All generated masters/public URLs and older archives are preserved elsewhere.

Rebuild from the matching source package:

1. Run `python3 Scripts/prepare-simulator-core.py` to stage the sanitized Azahar source/tools.
2. Run `python3 Scripts/build-openssl.py --target all`. It validates the included official archive and exact source tree, builds static arm64 iOS/Simulator libraries, and checks architecture/representative object platform tags. No OpenSSL app, provider module or shared TLS library is installed.
3. Run `Scripts/build-simulator-core.sh device` and `Scripts/build-simulator-core.sh simulator`. CMake's USE_SYSTEM_OPENSSL option selects the explicitly supplied bundled Apache2 static archives; it does not refer to an Apple OS library or invoke the GPL System Library exception. Both commands generate genuine matching core dSYMs.
4. Prepare the pinned MoltenVK dependency using the existing build/source recipe, then generate/check notices and build the Xcode project. Full licensed inputs, hashes and local patches are retained. Original resource headers are unchanged; the included per-resource source archives and Unifont source support inspection/modification of their preferred inputs. Generator scripts are historical Python2 tools, separate from the modern app build. Their individual licenses remain intact.

The current local work reused the existing idle core caches after preserving their prior binaries/configuration under build/LegalReview/CacheBeforeTLS; source modifications and old main Vendor binaries were not overwritten. Simulator/device core logs are in build/LegalReview. TLS-REPLACEMENT-VERIFICATION-22.json records explicit link paths, hashes, platform tags and new/absent version identifiers. Native app checks and local source packaging are separate from the legal distribution decision.

See Docs/Legal/RELEASE-22-LEGAL-DECISION.md. The GPL/Apple arrangement, actual import/crypto scope and naming review remain on the public-release hold. No claim about phone performance, broad game compatibility, or Apple acceptance follows from this repair.
