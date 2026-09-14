# Architecture and verification

## Components

- `AmbienceCore`: zone geometry, sampling, LAN packet encoding and local scene/music rendering.
- `GoveeStudio`: SwiftUI shell, native zone interaction, ScreenCaptureKit capture, UDP transport, optional cloud API and macOS Keychain storage.
- `ModeActivationQueue`: serial transitions between local output, cloud effects, room music and room scenes.
- `RoomOutputPlan`: validates participating devices and runs one output source per device.

Before hardware output, the application snapshots every participating device and writes recovery state. Frame delivery stops before restoration. In-flight cloud calls settle before cancellation restores devices. Failed restoration retains pending recovery data. Recovery restores basic light state, not arbitrary vendor animations.

## Automated checks

Run `./scripts/test.sh`. The baseline has 64 tests covering protocol checksums and frame length, sampling and zone bounds, multi-selection/drag behavior, audio reactions, palette behavior, mode switching, room routing, catalog identity validation, credential-store behavior and persisted scene choices.

Run `./scripts/build-app.sh` to compile the release binary, stage an app outside the checkout, sign it locally and verify the signature. The ZIP contains the app bundle only.

Tests do not require real lights or a real API key. Credential tests inject an in-memory store. LAN/cloud command acceptance is distinct from visible hardware behavior.

## Hardware evidence and limits

Local RGB and corrected segment streaming were visually confirmed on H606A, H61A0 and H61A2. Native music reactions were confirmed on all three models. On H606A, Cubic and Windmill visibly used multiple faces. This does not establish arbitrary per-face local control or compatibility with every firmware.

Whole-room original scene startup was exercised with two H606A devices and both strip models: all four commands were accepted by the cloud service. Physical appearance of that combined scene test was not independently confirmed. A split configuration with native music and Ambilight ran through the capture/output path; separate visual validation of that combination remains limited.

Keychain persistence was checked by saving through the UI, quitting, reopening and successfully starting cloud effects without re-entering the key. No keys are needed for automated tests.

## Protocol interop

The tested streaming frame uses dynamic length `2 + 3 * N`, a checksum and a maximum of 84 channels. A fixed `0xFA` length failed the physical test. Do not extend channel counts or claim inner/outer addressing without protocol and hardware evidence.

The development scripts are optional:

- `probe-lights.py`: bounded hardware test, reads the local workspace, changes actual lights and attempts basic restoration. Close the app and other controllers first. Its output contains private device addresses; do not publish it unchanged.
- `inspect-cloud-capabilities.py`: read-only H606A capability query with an interactive hidden key prompt. Writes private metadata only under ignored `.local/`.
- `Benchmark.swift`: synthetic sampling benchmark, not end-to-end light latency.

The implementation targets macOS 14+. Actual device validation took place on Apple Silicon/macOS 26; Intel and older macOS versions have not been verified. No universal compatibility or frame-rate guarantee is implied.
