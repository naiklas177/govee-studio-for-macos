# Credentials and private data

Never put API keys, tokens, LAN inventories, device IDs, local configuration files or unredacted diagnostic screenshots in commits or issue reports. The Govee key belongs in macOS Keychain; development scripts may ask for it interactively but must not save it.

If a credential is accidentally committed, revoke or rotate it at its issuer. Removing it from the latest file does not remove it from Git history. Contact the repository owner privately before sharing a suspected credential or vulnerability; do not paste the secret into an issue.

The publication checker is a guardrail, not a guarantee that a repository contains no sensitive information. Review staged changes and history before widening repository visibility.
