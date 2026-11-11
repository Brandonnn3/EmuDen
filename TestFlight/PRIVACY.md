# EmuDen privacy preparation

The app does not operate an account system, advertising SDK, analytics SDK or tracking system. Imported games, system data, in-game saves, play history and diagnostic logs are stored locally. The user grants access to selected files through Apple's document picker. Gamepad state, device/GPU information, thermal state and timing samples are used locally for play and diagnostics. A public static artwork site supplies illustrations and metadata as described below.

The app does not automatically upload its library, saves, Mii data, keys or logs. A user may explicitly share screenshots or diagnostic excerpts. Apple collects and delivers TestFlight diagnostics and tester feedback under its own TestFlight privacy terms; that behavior is distinct from automatic collection by the app. Imported software's behavior and user-enabled console services are outside a claim that all possible guest networking is impossible.

For the current app's own App Privacy questionnaire, the prepared answer is **Data Not Collected**, with **no tracking**. This records the app's lack of telemetry or uploaded user content; artwork requests still expose ordinary network information to their hosts. Hosting-provider request retention has not been independently audited. Reassess the disclosure before external distribution and if analytics, accounts, cloud sync, advertising or new services are added. Do not claim that Apple itself collects no TestFlight data.

## Game artwork

The app downloads a public catalog and original illustrations from `emuden-artwork-catalog.headyopossum2.chatgpt.site`. The site contains generated delivery images and game-title/ID metadata only. Libretro’s public thumbnail server (`thumbnails.libretro.com`) and its public GitHub indexes provide additional cover/scene fallbacks. Matching happens on the device. HTTPS requests expose the requested catalog/image path and normal network information, including the requesting IP address, to the host. ROM contents, save files, personal Mii data, account information and diagnostic logs are not sent. Downloaded artwork is cached locally and excluded from backup; downloaded images work offline. The app adds no analytics requests to these services. Images are fan illustrations or third-party artwork, not a hosted game-file catalog.

Build 10 can use the most recent local gameplay frame as a library preview when a game closes or the app goes into the background. Users can also choose a scene image through Files. These images stay in the app container and are never uploaded. Browsing previews does not start an emulator session. Menu sounds are original synthesized PCM files bundled in the app; haptic and sound preferences remain local.

Build 17 stores a chosen profile picture as a normalized local JPEG without its source metadata. It is not sent to the artwork host or widgets. Per-game preferences remain local. The WidgetKit extension shares at most four recent game IDs/titles and bounded downsampled thumbnails through the app's registered App Group. It performs no network requests and does not receive ROMs, saves, Mii resources or diagnostic logs.

## Required-reason manifests

`Resources/PrivacyInfo.xcprivacy` describes file metadata inside the app container (C617.1), user-selected files (3B52.1), own-app preferences (CA92.1) and elapsed-time/timer calculations (35F9.1). These support imports, local saves, preferences, menu-sound debounce and emulation timing.

The embed script places a separate `PrivacyInfo.xcprivacy` in each dynamic framework before signing:

- Azahar: file metadata inside the app container, C617.1, and emulation elapsed-time/timer calculations, 35F9.1. Binary imports include file metadata and monotonic clocks.
- MoltenVK: elapsed-time calculations and timers, 35F9.1. Binary import inspection found `mach_absolute_time` and `mach_continuous_time`.

The WidgetKit extension has its own `Widgets/PrivacyInfo.xcprivacy` for local shared-container file metadata (C617.1).

All four manifests declare no tracking domains and no collected-data types. These declarations describe the app's current implementation; they are not a server-side Apple validation result.

Build 9 adds a system share-sheet action for the owner to export a session log. It runs only when the user chooses it; no automatic diagnostics upload is added. Logs can include the game name, device/core settings, timing and game-session messages. The app explains this beside the share action.

References: [required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), [approved reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons), [TestFlight privacy](https://www.apple.com/legal/privacy/data/en/test-flight/).

Build 5 stores haptic and controller-layout preferences in this app's UserDefaults (`NSPrivacyAccessedAPICategoryUserDefaults`, CA92.1, own-app settings). Save-state checksums use the platform CryptoKit SHA-256 implementation locally. Save states and their timestamps stay in the app container.
