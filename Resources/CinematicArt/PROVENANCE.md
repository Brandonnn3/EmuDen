# Build 21 local artwork

Only the unbranded console illustration Console-3ds.png is shipped as a scene. It is an original image_gen output; the original prompt and generation record remain in Docs/Design/Build12-Console-Art/prompts.json. It depicts hardware-inspired form, without a manufacturer logo or game characters. This is a provenance record, not trademark/trade-dress certification.

Title-IDs.json and the title-only 3ds-artwork-index.json are used locally for library naming. Their pinned upstream attribution remains in Docs/Design/Build12-Console-Art/PROVENANCE.md and the dependency notices. Neither file fetches images in this release.

Users can import their own cover/background from Files. Fresh gameplay previews are stored locally. Old download caches are left intact but are not displayed. Older explicit image imports are retained using their custom marker. Widgets use a separate local-artwork snapshot directory.

The generated-character collection and its masters remain preserved in the original project, earlier source releases and artwork host. This candidate does not bundle it, query it or provide a hidden switch to it.
