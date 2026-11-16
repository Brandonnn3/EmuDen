# Build35 — artwork collections for all three consoles

Adds strict platform-scoped title/alias matching for the optional consoleGames array in a user-selected catalog. Legacy games remain 3DS entries; consoleGames require an explicit ps1 or gamecube platform and no 3DS program IDs. All entries keep the existing same-origin, SHA256, dimensions, size and bounded-parser validation. Duplicate titles on different consoles cannot select each other's artwork.

The bulk import plan includes all three consoles. Existing GameLibrary import triggers and production UIKit image storage are reused; manual image priority, console-background selection, offline persistence, disconnect/cancellation, age and network privacy behavior stay in effect. No provider is hardcoded or connected by default and no new artwork is bundled.

After updating, use the existing website link in Settings → Artwork catalogs → Connect a collection, Find matching artwork, Use catalog & fill artwork. Refresh once if an older catalog was remembered. Thereafter newly imported matching PS1/GC games use that selected collection. Collection15 currently contains 15 games per new console.

All build34 emulation, controls, graphics, saves and presentation are inherited. All four core binaries, source/dependency pins, sanitized resources and genuine symbols remain exact34/33. No commercial-game download, CPU JIT, new dependency, owner-phone access, binary upload or public release. Actual test, archive and portable-source results are recorded in BUILD-35-PROGRESS.md and the35 verification/freeze records.

Display launch correction: the launch host is a noninteractive UIKit background view held weakly, so OS age presentation uses the exact window containing the tapped library. Activation waits up to2seconds instead of silently returning during a display handoff; both fold panels constrain hit testing to their clipped bounds. The drawing subtree was split only to keep SwiftUI type checking bounded. Owner34 report is a brief starting overlay followed by no launch on inner display; native before-change6pose/console dispatch checks pass, so phone reproduction/verification is still required.

Separate known unresolved34 report: Mario Golf, Detective Pikachu and Ocarina of Time in-game3DS saving loops. Snapshot-vs-fresh-start comparison is pending. No reset, deletion or modification of owner game/save data or3DS core occurs.
