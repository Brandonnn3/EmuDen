# EmuDen — internal TestFlight handoff

This package prepares **EmuDen 0.1.0 (7)** for internal testing on iPhone and iPad. The current core supports 3DS. DS, GameCube, PlayStation and PlayStation 2 are future work, not advertised as available.

See [STATUS.md](STATUS.md) for the exact completion state. Build 7 passed the documented local archive and simulator checks. See STATUS.md for current artifacts; the earlier build 4 signed IPA remains preserved. Xcode created the live EmuDen app record with the chosen name/SKU/bundle ID/language. Build 3 was uploaded by the owner; the agent has not uploaded build 7; the remaining TestFlight text is prepared locally for entry after upload.

The app's bundle ID remains `com.brandonaleman.Emulator`, preserving continuity with the existing phone build. The visible product, icon, library header and display name are EmuDen. The Xcode project and scheme remain named `Emulator` internally.

## Upload handoff

1. The app record is already created: **EmuDen**, `com.brandonaleman.Emulator`, team `NKC9X96J5A`, SKU `EMUDEN-IOS-001`, English (United States). Do not create a second record for this bundle ID.
2. Open `build/TestFlight/EmuDen-0.1.0-7.xcarchive` in Xcode Organizer and select **Distribute App → TestFlight Internal Only**. This archive includes all three matching dSYMs. The existing signed-in Xcode account handled cloud-managed distribution signing for build 4; distribution signing for build 7 happens in this flow. A build-7 IPA has not been exported yet. Build 4's signed IPA is preserved at `build/TestFlight/EmuDen-0.1.0-4-Internal/EmuDen.ipa`.
3. Validate, then upload. This preparation does not upload a build, publish the app, submit an external beta, invite testers, or accept agreements.
4. After processing, complete any encryption question using the technical inventory in `EXPORT-COMPLIANCE.md`. Do not describe this app as using only Apple's cryptography: the emulator includes third-party cryptographic code.
5. Create the internal group **EmuDen — Internal**. Add the uploaded build and your existing App Store Connect team user. Internal testers must be eligible team members; a feedback email alone does not make someone an internal tester.
6. Paste `en-US/what-to-test.txt` into What to Test and `en-US/beta-description.txt` into Beta App Description. Feedback email and optional future beta-review contact details are saved in `Private/Contact.json`, excluded from source packages and version control.

Public support/privacy URLs, App Store screenshots, age-rating publication and external Beta App Review are deferred for this internal beta. Draft privacy/support copy is included for later hosting. No fake URLs have been entered. Internal builds still need Apple processing and appropriate signing.

## Prepared information

- `AppInformation.json`: name, subtitle, language, bundle ID, SKU, version/build, categories and internal group.
- `en-US/`: beta description, What to Test, review notes and future App Store description/promotional text/keywords.
- `PRIVACY.md`: on-device data behavior and the privacy-manifest reasons used by the app and each embedded framework.
- `EXPORT-COMPLIANCE.md`: cryptography inventory and the remaining App Store Connect declaration.
- `Private/Contact.json`: supplied feedback email and beta-review contact. The phone number is not bundled in the app or public drafts.
- `ExportOptions.plist`: an **internal-only**, local-export configuration. Its destination is `export`, not `upload`.
- `SOURCE.md`: source-package contents and rebuild instructions for the GPL-based core.

## Rebuild

Run `Scripts/archive-testflight.sh` from the SSD project. It archives the Release configuration and validates local packaging. It never uploads. The optional local export command is:

```sh
xcodebuild -exportArchive \
  -archivePath build/TestFlight/EmuDen-0.1.0-7.xcarchive \
  -exportOptionsPlist TestFlight/ExportOptions.plist \
  -exportPath build/TestFlight/Export
```

Re-export requires App Store distribution signing access. The local CLI could not access the Xcode account, but the signed-in GUI account successfully exported using **Cloud Managed Apple Distribution**. Build 4 was exported successfully through that GUI flow; build 5 currently has a validated local archive. No build 5 upload was performed.

Apple references: [upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds), [internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/), [test information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/).
