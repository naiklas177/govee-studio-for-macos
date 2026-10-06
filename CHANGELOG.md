# Changelog

## 2026-10-07 — Significantly lower CPU use for the live UI

Music + Ambilight now spends substantially less CPU time updating the interface. Live telemetry refreshes the small meters, status labels and color preview without invalidating the entire music and settings layout.

- **About 59% less CPU time in the repeated synthetic hybrid UI benchmark:** average utilization fell from **6.59% to 2.73% of one CPU core**, across three runs per variant with identical inputs.
- Skip fallback preview-color generation when live colors are already available.
- Preserve capture frequency, audio analysis, color sampling, smoothing and light-output timing. The optimization does not lower lighting quality or frame-rate settings.
- Add an [offline UI benchmark](scripts/benchmark-ui.sh) with synthetic data and no screen/audio capture or lamp output. The compared final UI renders were byte-identical.

**Measurement scope:** these are local, offscreen SwiftUI benchmark results with 5 Hz telemetry, not a 59% reduction in total app CPU usage. End-to-end CPU savings depend on the workload and window state; the animated idle preview remains a separate optimization opportunity.

Implementation: [7cc0d98](https://github.com/naiklas177/govee-studio-for-macos/commit/7cc0d9815515d137c3e78fe9dc7e78eefece9462).
