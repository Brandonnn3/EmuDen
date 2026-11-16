# EmuDen privacy reference — build 21

Prepared policy supplement, 12 November 2026. Public policy: https://emuden-support.headyopossum2.chatgpt.site/privacy.html. Developer/contact: Brandon Aleman, Godofwaa@gmail.com. No private review phone is public.

Build21 and the build22 legal-remediation candidate store imported software, system resources, native saves, snapshots/history, settings, profile and artwork images locally. WidgetKit reads a bounded local App Group snapshot, without downloading. No account, advertising, tracking SDK or developer analytics backend is added. The release does not contact the earlier artwork gallery, Libretro thumbnail service or GitHub image indexes. Old online preferences cannot enable artwork requests. Old download files are preserved but ignored; explicitly imported images and new captured previews remain usable locally.

Earlier builds behave differently: build19 asks before online artwork; builds18 and earlier requested it automatically. Those hosts may receive asset paths and connection information. Removing artwork requests in21 does not erase prior provider records. The public policy must retain this version distinction while those builds are in use.

Build37 removes the blanket local adult-access choice. Supported iOS uses Apple's regional age service transiently only where applicable; EmuDen collects no birth date or identity document and sends no age band to an EmuDen server. Imported guest software may have its own emulated network behavior; that is not claimed to be disabled.

Apple handles StoreKit payments and platform diagnostics under its own practices; optional tips are locally verified and do not unlock content. Users can export logs voluntarily; export first opens the system share sheet rather than uploading automatically. Support email is voluntary and may be retained to handle the request. Websites are separate public pages served through Sites/Cloudflare, which may retain security/request data and use provider security mechanisms; the native app has no embedded web view or automatic policy-page fetch.

Files may be present in device/iCloud backups under the user's OS settings. Deleting the app removes local app storage subject to those backups; source files in Files/iCloud are separate. Contact the public support email about developer-held correspondence; EmuDen cannot delete another provider's records.

Prepared App Privacy answer: no data collected by this native build/developer partners through automatic artwork or analytics requests; no tracking. Optional user-initiated correspondence is not a promise of no support records. Live App Store Connect must be reconciled and published before submission.

## Build23 optional artwork catalogs (not yet publicly published)

No artwork provider is included or enabled by default. In Settings → Artwork catalogs, users can preview a compatible HTTPS index, then connect it to fill matching missing covers/backgrounds. Preview requests the index; image requests begin after applying. Matching uses title IDs/names locally. The user-selected host receives ordinary network information, including IP address and requested catalog/image paths; paths may identify a title. EmuDen does not upload ROMs, saves, Mii data or the complete library. Requests use an ephemeral session without stored cookies/credentials. Provider retention and rights depend on the chosen source and have not been declared cleared.

Remembered catalog metadata and imported images remain on the device, subject to OS backup settings. Cached images work offline. New game imports can use the connected source without another per-image choice. Stop cancels a fill; Disconnect stops future requests while retaining saved images. The existing per-game Reset artwork removes that game’s selected images. The public policy and store privacy answers require reconciliation before distribution. Earlier build21/22 local-only behavior remains as described above.

## Build25 optional original-cover folders (development; no public release yet)

A user can separately select an HTTPS Named_Boxarts collection folder. Nothing is fetched from a default cover service. After selection, EmuDen matches cover filenames locally using the game's title ID and, when consistent with that identity, its region/revision tags. Initial fill and later game imports request only matching cover PNGs from the chosen host using the same bounded, ephemeral, cookie/credential-free HTTPS transport. The host receives the requested path and normal connection information. No game-file contents, complete library, saves or system data are uploaded. No covers are rehosted by this feature.

Cover files and their selected source URL are stored locally and can appear in OS backups. Covers remain available offline and after disconnecting the source. Manual images take priority; the separate background catalog and console preference are retained. Stop, gameplay and app backgrounding cancel pending fetches. Widgets read local downsampled snapshots without network access. Public policy/store forms and chosen-source rights remain subject to the existing release hold; this development note is not a publication or a claim of permission for third-party artwork.

## Build27 local motion input

During active3DS play, CoreMotion provides gyroscope and acceleration samples for motion controls. EmuDen processes these transiently on the device, without a separate motion history or automatic upload. The player stops updates on pause, background and close. Users can disable Motion controls globally or per game. Optional artwork-host behavior remains as described for builds23/25; no default provider is added. This supplement is a local draft, not a public policy update.
