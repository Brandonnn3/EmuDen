# EmuDen — internal TestFlight handoff

Current signed artifacts are **EmuDen 0.1.0 (18)**. Only Nintendo 3DS is playable. See [STATUS.md](STATUS.md) for the technical evidence and artifact paths.

**Public App Store submission is on hold.** Technical build validation is separate from copyright permissions, GPL distribution obligations, privacy/export declarations and Apple's review decision. Read [the legal/App Review audit](../Docs/Legal/REVIEW-2026-11-11.md) and run `python3 Scripts/validate-app-store-readiness.py` before preparing a public release. The artwork automation is paused; the existing public artwork site has not yet been changed.

## Internal handoff

1. Reuse the existing **EmuDen** app record, bundle ID `com.brandonaleman.Emulator`, SKU `EMUDEN-IOS-001`. Do not create a duplicate.
2. The archive is `build/TestFlight/EmuDen-0.1.0-18.xcarchive`; matching source is `build/TestFlight/EmuDen-0.1.0-18-source.tar.gz`. The archive has four real matching dSYMs, including the WidgetKit extension. Builds 14–17 remain preserved.
3. The configured export is **TestFlight Internal Only** with destination `export`. No build-18 upload, physical-phone install or distribution IPA export has been performed by the agent. Do not treat this configuration as a completed public submission.
4. Complete actual encryption/export answers from `EXPORT-COMPLIANCE.md` before assigning a processed build. The embedded core includes third-party cryptography; an exemption has not been certified.
5. Internal testers must be eligible App Store Connect team members. Private review contact and phone remain in `Private/Contact.json`. The owner separately authorized publishing Godofwaa@gmail.com as the support/privacy email; no review phone or account/signing data is public.
6. Use `en-US/what-to-test.txt` and `en-US/beta-description.txt` for internal beta information. Deliver the applicable matching source/notices to binary recipients as required; matching source releases are now available from https://github.com/Brandonnn3/EmuDen, with source-page links and anonymous checksum verification.

## Public release prerequisites

`AppStoreReadiness.json` records unresolved artwork rights, combined-work/source licensing, GPL/store terms, dependency notices, public support/privacy links, privacy disclosure, encryption/export classification, emulator-content/age requirements, branding and final device testing. Its fields are evidence records, not an Apple approval or a legal opinion. Public URL fields point to the separately prepared support/privacy/source Site; verify anonymous access in the latest preparation report. The App Privacy answer remains unconfirmed; do not submit it as a final declaration.

The App Store description draft now reflects implemented save-state/widget features. The final binary, screenshots, policy pages, license/source access and metadata must be reviewed together. The owner authorized public source/support publication and retained artwork. No Apple agreement, legal classification or publisher permission has been accepted or invented. The source grant does not convey third-party artwork rights.

## Files and validation

- `AppInformation.json`: current identity, internal distribution intent and public-release hold.
- `en-US/`: local descriptions, review notes and test instructions.
- `PRIVACY.md`, `EXPORT-COMPLIANCE.md`, `SOURCE.md`: current implementation, unresolved declarations and source rebuilding.
- `Private/Contact.json`: private internal feedback/review contact; excluded from source packages.
- `ExportOptions.plist`: local internal-only export configuration, never an automatic upload.

`Scripts/archive-testflight.sh` builds and runs technical packaging checks. Preserve existing archives and increment the build before archiving any modified app. It does not certify legal compliance. Do not overwrite existing matching source packages when working on new changes.

Apple references: [upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds), [internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/), [test information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/), [review guidelines](https://developer.apple.com/app-store/review/guidelines/).
