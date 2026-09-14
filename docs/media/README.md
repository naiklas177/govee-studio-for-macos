# Documentation media

These assets were generated specifically for Govee Studio's repository presentation.

## Sources

- `scenes.png`, `music.png`, `ambilight.png`: the actual SwiftUI app views rendered into an offscreen AppKit view using synthetic demo fixtures. No desktop/window capture, real device names, device identifiers or user configuration was used. The German interface has not been translated or composited for the images.
- `prism-drift.mp4` / `.gif`: the project's `ShowRenderer` running the local Prism Drift scene on synthetic channels.
- `music-reactor.mp4` / `.gif`: the project's Prism Drive music reaction driven by mathematically generated bass/mid/high levels. No recorded audio was analyzed.
- Video framing and captions: original layout in `scripts/ExportMedia.swift`. The clips have no audio track. GIFs are smaller looping copies of the MP4s.

No commercial recordings, movie clips, YouTube content, stock footage, downloaded graphics or Govee-provided animation recordings are included. The app interface uses its existing macOS system controls, fonts and symbols. Govee is named to identify device compatibility; no affiliation is claimed.

This provenance record does not grant a license to the project or to third-party names/system assets. Repository visibility remains private and project licensing is still undecided.

## Reproduce

On macOS with full Xcode and `ffmpeg` available:

```sh
./scripts/export-media.sh
```

The exporter is a separate development executable compiled with `MEDIA_EXPORT`. That configuration skips the normal model startup before any configuration-file loading, network discovery, capture or Keychain access. It never starts a light session. The normal app build does not enable this flag.

Screenshots use `NSHostingView` bitmap rendering, not a screenshot of the user's desktop. Clips render at 960 × 540, 12 fps, for six seconds; GIF copies are 720 pixels wide. Intermediate frames stay under ignored `.local/media-frames/`.

The screenshots and representative frames from both clips were visually reviewed. Both MP4 files were checked for duration, dimensions, decodability and absence of audio. `manifest.json` records the exact reviewed binary checksums. Regeneration requires another review and updated checksums before publication.
