# Build27 privacy preparation

No account, advertising SDK, tracking SDK or developer analytics backend is
added. Games/system imports, saves/history, library metadata, per-game settings,
chosen images and diagnostic logs stay in local storage. User-initiated log
sharing uses the system share sheet. Apple controls its TestFlight diagnostics
and StoreKit payment processing separately.

CoreMotion supplies gyroscope and gravity-inclusive acceleration during active
3DS play. Samples are processed transiently in memory, without a separate
motion history or automatic upload. Pause, background and close stop updates;
Motion controls can be disabled globally or per game. NSMotionUsageDescription
explains this use. PS1 does not start motion sampling.

Artwork providers are never configured by default. Previewing/connecting a
user-selected HTTPS catalog or cover folder exposes ordinary network details
and requested paths to that host. Matching stays local; ROMs, saves, Mii data
and the complete library are not uploaded. Requests are bounded and use an
ephemeral session without stored cookies/credentials. Provider retention and
rights remain source-dependent. Disconnect stops future requests and retains
saved images for offline use. Widgets read only a bounded local App Group
snapshot without network requests.

The existing required-reason manifests cover own-container/user-selected file
metadata, own-app preferences and elapsed-time/timer APIs. They declare no
tracking domains or collected-data types. This technical inventory does not
replace the live App Privacy questionnaire or establish chosen-host retention.
Guest software may use emulated networking; it is not claimed disabled.

See Privacy-policy-draft.md and Submission/PrivacyAnswers.json for the local
policy supplement and unsubmitted draft. Public privacy/store reconciliation
remains held. Historical releases and published policies are preserved; this
file does not publish a policy change.
