# Initial public submission plan — build 19

Owner confirmed: free app, United States initially; optional tip jar if it can be configured, otherwise free. Build 18 is currently under owner phone testing and remains unchanged.

## Store entry

- Reuse EmuDen, bundle `com.brandonaleman.Emulator`, SKU `EMUDEN-IOS-001`.
- Price: free. Availability: United States only. No subscription, ads or paid feature unlocks.
- Version 0.1.0, build 19. Only 3DS is playable; release menus hide unfinished console options.
- Support: https://emuden-support.headyopossum2.chatgpt.site/support.html
- Privacy: https://emuden-support.headyopossum2.chatgpt.site/privacy.html
- Source: https://emuden-support.headyopossum2.chatgpt.site/source.html
- Use a manual release after App Review. Do not select automatic publication while rights/distribution questions remain open.

## Optional tips

Three repeatable StoreKit consumables are drafted: `com.brandonaleman.Emulator.tip.small`, `.medium`, `.large`. Suggested US tiers: $0.99, $2.99, $4.99. The UI uses Apple's returned localized price, never an assumed display price. No tip changes available features/content. Refunds and purchase records are handled by Apple; no developer purchase-history server is added. Consumables do not create a restorable entitlement.

Apple requires an active paid-apps agreement, banking/tax setup as applicable, and configured/reviewed IAP products before live purchase availability. These cannot be inferred from a signed development archive. If live products are unavailable, the entire tip section stays hidden and the release remains free. The `.storekit` fixture is UI-test-only and must not ship in the app.

## Age/content entry

Build 19 treats imported software as unrated and requires a local adult declaration (18+) before launching an imported entry, including widget/link launches. Under-18 choices restrict those launches; the bundled licensed Homebrew Menu demo remains accessible. The declaration can be reviewed in Settings. No birth date/document/account or remote age profile is collected.

Prepare an adult-targeted age-rating override (18+ where offered) for unrestricted, unrated imports, with age assurance declared present. This is an engineering compliance design, not an official ESRB/PEGI rating. The actual App Store questionnaire must describe the shipped app and its imports honestly. No gambling service, messaging, advertising or commercial game collection is supplied.

## What remains outside this prepared record

Native Safari access recovered after the owner unlocked the Mac. The existing EmuDen app record (6832247608) now has a saved0.1.0 draft: description/promo/keywords/support/copyright/private Apple review contact and notes; no sign-in; manual release; freeUSD0 pricing; UnitedStates-only availability (1available/174excluded); Mac/VisionPro compatibility availability off; subtitle and Games/Entertainment categories. The privacy URL and two data types are saved. Product Interaction is configured as App Functionality, linked, no tracking; Other Data setup remains unfinished because the Mac locked again. The label has not been published. No AddforReview/Submit, rights attestation, new agreement, live IAP products, app upload or AppReview approval occurred.

The development archive's new capabilities and profiles validate. Local CLI public export still reports NoAccounts/no local iOSDistribution identity and an old Store profile; a successful development archive does not resolve distribution signing. Finish local AppStore export through the owner's Xcode account when desktop access resumes.

Artwork/name and GPL/store distribution questions remain explicitly recorded, rather than certified by owner consent. Owner phone tests currently cover build18; the new release controls require final device/regional age-service validation too.
