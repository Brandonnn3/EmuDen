# EmuDen privacy reference — build 19

Published policy: https://emuden-support.headyopossum2.chatgpt.site/privacy.html. Effective November 11, 2026. Developer/contact: Brandon Aleman, Godofwaa@gmail.com. No private review phone is published.

Imported files, system resources, native saves, save states, history, per-game settings, chosen images and logs are local. Widgets read a bounded local App Group snapshot of recent titles and cached images, without downloading. No advertising, tracking SDK, developer telemetry or EmuDen account is added. Users choose whether to share diagnostic logs; shared logs may include titles/device/settings/timing details.

Build 19 asks before online artwork downloads. Declining or disabling online artwork retains bundled, cached and user-selected pictures. Requests are HTTPS with persistent cookies, credentials and URL caching disabled; the app has a separate bounded image cache. Hosts still see connection metadata and requested image/catalog paths. Matching stays on-device; game files, saves, Mii data, profile pictures and logs are not uploaded by artwork requests. Builds 18 and earlier requested artwork automatically.

Because provider-controlled request logging and retention are not specifically audited, the label conservatively declares Product Interaction and Other Data Types, linked to the user, for app functionality. This covers requested title/artwork paths and potentially retained IP/user-agent metadata, even without an EmuDen account. It does not claim Data Not Collected or promise host-log deletion. Actual hosts are the public EmuDen catalog, Libretro thumbnails and GitHub index sources; the public website uses Sites/Cloudflare, which may add security scripts or cookies. Provider policies are linked on the public page. Reassess the label if provider purposes or integrations change.

A local adult-access declaration is stored without a birth date or identity document. On supported iOS versions, regional eligibility and age assurance use Apple's Declared Age Range service where required. The app uses the returned age band only to decide access; no band, document or identity record is sent to a developer server. Imported software can have its own emulated network behavior; there is no claim that the guest HTTP service is disabled.

Optional tips use Apple's StoreKit. Apple handles payment details and purchase history. The app verifies/finishes transactions locally; there is no developer purchase-history server or feature entitlement. Apple/TestFlight data collection is governed separately by Apple.

Deleting the app removes local app storage subject to user-controlled backups; imported originals in iCloud/Files remain with their provider. Support email is voluntary and may be retained to address the request and necessary records. Provider-controlled records cannot be remotely erased by this app. The public policy describes these limits and contact/deletion options.

Prepared label answers: `Submission/PrivacyAnswers.json`. No App Store Connect privacy form has been submitted by this work.
