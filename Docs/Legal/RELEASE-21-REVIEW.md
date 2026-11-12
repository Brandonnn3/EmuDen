# Build 21 release review — 12 November 2026

Scope: a free United States-only, 3DS-only candidate, without the earlier online character/cover collection. This document is an engineering/compliance record, not a legal opinion or an Apple decision. No lawyer, publisher or other third party has been contacted; no new agreement has been accepted.

## Artwork mitigation completed in the candidate

The candidate removes bundled character/concept illustrations, their catalog seed and online image UI. The remote catalog actor is not in the app target. Local artwork storage never constructs a request; earlier online preferences cannot enable one. Old automatic downloads remain preserved on disk but are not read. Explicit local user imports, fresh captured previews and original console artwork remain. A separate WidgetKit namespace prevents old downloaded images being reused by the extension. The original glass handheld icon and synthesized sounds are retained. Asset hashes and exact provenance are in ASSET-REGISTER-21.json.

All original masters, earlier sources/archives and the public artwork site's existing URLs/assets remain untouched in the original project. They are outside this release candidate; their third-party character rights are still unresolved. Moving those images to a different server or naming an option “public” would not settle those rights. No claim is made that all cover thumbnails are unlawful: this candidate simply avoids distributing them before a specific basis has been evaluated.

The retained console illustration and native shell are hardware-inspired and unbranded. The icon has no Nintendo/Sony logo or game character. These are provenance/design observations, not a certified trade-dress clearance. Compatibility names are used descriptively with a non-affiliation statement. Store captures must show only the licensed demo and original UI.

## Actual GPL/Apple question still requiring a distribution decision

The owner has already licensed original frontend/bridge/widget/tool source under GPL-3.0-or-later. The pinned Azahar core is also GPL-3.0-or-later; the resource-policy patch removes bundled data defaults without changing that license. It cannot be relicensed or given an App Store exception by the frontend owner alone. Matching sources, deterministic patches, complete upstream core source, rebuilding/install instructions and 84 notice texts are supplied. Source access and attribution are concrete obligations addressed here; they are not a blanket answer to store conditions.

Specific primary clauses: GNU GPLv3 sections 6 and 10; Apple Standard EULA scope-of-license clause; Apple Developer Program License Agreement section 3.3.2(v), Schedule 1 section 3.2 and Exhibit B section 2. The Standard EULA has an exception for open-source permissions in its copying/modification restriction, but also has device/usage/non-transferability conditions. Apple's custom-EULA route still requires minimum terms. A custom EULA should not be filed as a supposed workaround without resolving that interaction.

Questions for qualified review: Does the actual free US App Store delivery, including applied Usage Rules and any copy protection, impose further restrictions prohibited by section 10? Does section 6 Installation Information apply to this software-only transaction, and if so are the supplied build/install steps sufficient given Apple's signing controls? What exact distribution/EULA arrangement satisfies both the upstream grants and Apple's mandatory terms? This record does not assume that every GPL app is prohibited, that another app's approval transfers to EmuDen, or that publishing source settles these questions.

No proprietary replacement core, private signing key, DRM bypass or unauthorized upstream relicensing is introduced. Review or additional permission, if required, must address the actual core rights holders and terms.

## Name and store state

Bounded exact-name US App Store and search-engine checks have not established a conflicting emulator app, but are not a comprehensive trademark search. An existing EMUDEN electrical-connector company was identified at emuden.com. Similar-mark/relevant-software/common-law screening remains incomplete; no USPTO serial number, clearance or publisher permission is invented. The official USPTO dynamic search interface could not be inspected because browser/native access is unavailable while the Mac is locked.

The prior App Store Connect draft is free, USA only, manual release. Build21's local artwork behavior requires replacing the prior draft's artwork collection disclosure. The prepared no-developer-collection answer is based on no artwork/analytics backend; user-provided files and age decisions remain local. Voluntary support and separate website/provider/Apple services are described in the policy; guest software network behavior is not falsely claimed disabled. The final live questionnaire, regional age-service device check, signed public export and final phone validation remain separate checks.

## Primary materials

- https://developer.apple.com/app-store/review/guidelines/ (4.7, 5.1, 5.2)
- https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
- https://developer.apple.com/support/terms/apple-developer-program-license-agreement/
- https://developer.apple.com/help/app-store-connect/manage-app-information/provide-a-custom-license-agreement/
- https://raw.githubusercontent.com/azahar-emu/azahar/2127.0-rc1/LICENSE.txt (exact pinned license also supplied as LICENSE.txt)
- https://developer.apple.com/app-store/app-privacy-details/
- https://www.uspto.gov/trademarks/search/comprehensive-clearance-search-similar-trademarks

No App Store binary has been uploaded, selected or submitted by this preparation. The release hold remains until these actual outstanding items have evidence.

## Core default-data correction

The audit found ENABLE_BUILTIN_KEYBLOB=ON in both baseline build caches and a fallback HTTP client certificate/key in upstream source. The earlier blanket store wording was too broad. Build21 removes those includes and runtime fallbacks, uses rebuilt binaries with negative checks for all three known payload arrays, and supplies derived source with those three unused data headers replaced by notices. Prior raw source/archive releases are preserved separately. This concrete packaging correction does not establish a general anti-circumvention/IP or Apple-distribution ruling; decrypted software and authorized user-provided resources are the intended scope. Qualified distribution review must cover actual imports/crypto functionality as well as GPL/store terms.

Current technical validation: the data-free core boots the existing local Mario Golf and Ocarina copies and passes homebrew/save-history native checks in owned Simulator. The structured offline viewer preserves all84 notice texts; a test verifies exact reconstruction of the full notice bundle. Apple age-service unavailability times out and fails closed, with signed-device regional/link checks still outstanding. All four final archive symbols/profiles pass. No App Store export, phone validation, rights opinion or Apple acceptance is implied.
