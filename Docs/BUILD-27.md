# EmuDen0.1.0 build27 — internal player candidate

Nintendo3DS and PlayStation remain the only included emulators. GameCube26
research is separate and unavailable in release/default menus.

- Cover tiles keep their portrait shape on wide and narrow displays; image
  drawing preserves aspect instead of squeezing the image into its tile.
- PlayStation supports native1x and NEON enhanced2x internal resolution.
  High-resolution modes and most2D elements retain their original detail.
- PlayStation offers1x,1.5x and2x playback. Audio follows via public
  AVAudioUnitVarispeed, so fast-forward raises pitch. Actual speed depends
  on available performance. Each new session begins at1x.
- Active Duo fold regions move PS1 video to one side with optional speed,
  FPS, quick-save/load and touch controls on the other. Disable all four
  for a blank panel. Controllers hide touch controls; flat landscape
  controller play retains full-display presentation.
- 3DS receives gyroscope and gravity-inclusive accelerometer samples through
  CoreMotion at60Hz, using pinned-core units and display-axis transforms.
  Motion is on by default, configurable per game, and stopped on pause,
  background and close. No motion stream is uploaded. Real sensor gameplay
  still needs phone testing; Simulator fixtures verify the interface only.
- Existing per-game3DS profiles migrate with their prior choices intact.

Current verification is recorded in BUILD-27-PROGRESS.md. No27 phone test,
TestFlight upload, public publication, legal clearance or Apple acceptance
is claimed. Optional user-selected artwork sources, import/age/privacy
safeguards and source/resource sanitization are preserved.
