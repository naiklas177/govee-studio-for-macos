# Documentation media

These assets were generated specifically for Govee Studio's repository presentation.

## Sources

- `scenes.png`, `music.png`, `ambilight.png`: the actual SwiftUI app views rendered into an offscreen AppKit view using synthetic demo fixtures. No desktop/window capture, real device names, device identifiers or user configuration was used. The screenshots use the app's English language setting.
- `prism-drift.mp4` / `.gif`: a scripted walkthrough of the actual app with Neon-Schlat, Meteor Shower, Prism Drift and Liquid Chrome on synthetic channels.
- `music-reactor.mp4` / `.gif`: a scripted walkthrough of the actual music interface with Spectrum, Bass pulse, Prism Drive and Glitterstorm, driven by mathematically generated bass/mid/high levels. No recorded audio was analyzed.
- Video frames: the real `StudioView` rendered offscreen by `scripts/ExportMedia.swift`; simulated parameter changes are scripted, not captured mouse interactions. The clips have no audio track. GIFs are smaller looping copies of the MP4s.

No commercial recordings, movie clips, YouTube content, stock footage, downloaded graphics or Govee-provided animation recordings are included. The app interface uses its existing macOS system controls, fonts and symbols. Govee is named to identify device compatibility; no affiliation is claimed.

This provenance record does not grant a license to the project or to third-party names/system assets. The repository is public for inspection; project licensing is still undecided.

## Reproduce

On macOS with full Xcode and `ffmpeg` available:

```sh
./scripts/export-media.sh
```

The exporter is a separate development executable compiled with `MEDIA_EXPORT`. That configuration skips the normal model startup before any configuration-file loading, network discovery, capture or Keychain access. It never starts a light session. The normal app build does not enable this flag.

Screenshots use `NSHostingView` bitmap rendering, not a screenshot of the user's desktop. Clips render at 1440 × 980, 24 fps, for twelve seconds; GIF copies are 768 pixels wide at 12 fps. Intermediate frames stay under ignored `.local/media-frames/`.

The screenshots and representative frames from both clips were visually reviewed. Both MP4 files were checked for duration, dimensions, decodability and absence of audio. `manifest.json` records the exact reviewed binary checksums. Regeneration requires another review and updated checksums before publication.
