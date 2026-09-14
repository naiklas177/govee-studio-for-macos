# Govee Studio development

- Native macOS SwiftUI/ScreenCaptureKit app. Ambilight, local scenes and music run locally. Optional Govee scene library uses official HTTPS endpoints. User-selected credential persistence must use macOS Keychain only, never source, JSON, UserDefaults or logs. Scene metadata may be cached in Application Support.
- Build with `./scripts/build-app.sh --install`; tests with `./scripts/test.sh`. Scripts prefer full stable Xcode. Do not change global xcode-select.
- The automatic Razer frame length is `2 + 3 * N`, not a fixed 0xFA. The latter was physically tested and failed on all four local controllers. Preserve the regression test and 84-segment limit unless protocol evidence supports an extension.
- Hardware-tested models: H606A, H61A0, H61A2. Never equate a successful UDP send or a devStatus RGB field with visible segment output. Streaming does not update the RGB field in devStatus on these devices.
- App state lives in user Application Support. Never overwrite user layouts or calibration with fabricated physical arrangements. Initial segment counts remain explicitly uncalibrated.
- Before output, snapshot all participating lights and write recovery state. Stop frame delivery before restoring. Preserve cancellation, sleep, quit, and crash-recovery behavior.
- Only one controller owns UDP 4002. Close the app before the Python probe. Hardware tests change actual lights: keep them bounded, announce the pattern, and restore state.
- Capture images never go to disk or network. UI screenshots used for QA may contain private underlying windows; do not publish them.
- Bundle outside the synced workspace before signing; deliver a zip and install under ~/Applications. File Provider FinderInfo breaks signing in this workspace.
- Build artifacts, diagnostic captures and live IP inventories belong under ignored .build, dist, or .local. No secrets or screen frames in the repository.

- Before publishing, inspect the exact staged files with `python3 scripts/check-publication.py`. Keep local session notes and inventories out of history. No project license has been chosen yet.
