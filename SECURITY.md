# Security Policy

This project wraps Proton Mail Bridge and handles software that can access decrypted mailbox data. Please treat security issues conservatively.

## Reporting a vulnerability

Do not include real Proton credentials, Bridge-generated passwords, mailbox contents, tokens, private keys, or other secrets in a public issue.

For a sensitive vulnerability, use GitHub's private vulnerability reporting for this repository when available. For non-sensitive bugs, a normal GitHub issue is fine.

If a secret was accidentally committed, assume it is compromised: revoke or rotate it first, then remove it from the repository history as appropriate.

## Security boundaries

- Proton account credentials are used only by Proton Mail Bridge during authentication.
- Runtime Bridge state and the GPG/password-store data under `/data` are sensitive and must never be committed.
- IMAP/SMTP listeners should remain private to the deployment and must not be exposed directly to the public internet.
- Protocol-level IMAP/SMTP logging should not be enabled in normal operation because it may contain decrypted mail data.
- Published images must be built from the Dockerfile in this repository and the downloaded Proton package must pass Proton's signature verification.

## Supported versions

Until the first stable release, only the current `main` branch and most recent published image are supported.
