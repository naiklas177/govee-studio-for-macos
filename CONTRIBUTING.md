# Development

This repository is public for inspection and has no open-source license. Please coordinate changes with the owner.

1. Install full Xcode with Swift 6+.
2. Run `./scripts/test.sh`.
3. Build with `./scripts/build-app.sh`; add `--install` to update the local app.
4. Keep hardware tests bounded, and verify visible output separately from successful commands.

Preserve session cancellation and recovery ordering. Do not copy scene IDs across devices, infer panel topology from marketing names, or change serialized identifiers without migration. The existing app identifier also identifies its Keychain entry and macOS permissions.

Before sharing a change, stage only source/docs/tests/scripts and run `python3 scripts/check-publication.py`. Do not attach your Application Support folder, capability dump, private screenshots, API key, device IDs or LAN addresses. Use synthetic examples in tests and reports.
