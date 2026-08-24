# Security Policy

This project wraps Proton Mail Bridge and handles software that can access decrypted mailbox data. Please treat security issues conservatively.

## Reporting a vulnerability

Do not include real Proton credentials, Bridge-generated passwords, mailbox contents, tokens, private keys, Bridge state, or other secrets in a public issue.

For a sensitive vulnerability, use GitHub's private vulnerability reporting for this repository when available. For non-sensitive bugs, a normal GitHub issue is fine.

If a secret was accidentally committed, assume it is compromised: revoke or rotate it first, then remove it from repository history as appropriate.

## Security boundaries

- Proton account credentials are used only by Proton Mail Bridge during authentication.
- Runtime Bridge state and the GPG/password-store data under `/data` are sensitive and must never be committed.
- Bridge-generated IMAP/SMTP credentials are secrets even though they are local credentials; do not commit or log them.
- IMAP/SMTP listeners should remain private to the deployment and must not be exposed directly to the public internet.
- In the intended `proton-mcp` deployment, Bridge remains loopback-only inside a shared container network namespace rather than being published to the LAN.
- Protocol-level IMAP/SMTP logging should not be enabled in normal operation because it may contain decrypted mail data.
- Do not start a second Bridge CLI process inside an already-running Bridge container; use a one-shot container against the same persistent state after stopping the normal Bridge process.

## Source and image integrity

The image is built directly from Proton's public source rather than from a downloaded binary package.

- `Dockerfile` must pin both the intended Proton Mail Bridge version and an immutable full upstream commit SHA.
- The build must fetch and checkout exactly that pinned commit and verify the resulting `HEAD` before compiling.
- Use Proton's upstream headless build target (`make build-nogui`).
- Build compilers and source-control tooling must remain outside the final runtime image.
- CI should continue to build the real pinned source, verify non-root runtime behavior, smoke-test the Bridge binary, scan the Docker/IaC configuration, and scan the final runtime image.
- Published images must be produced from the repository's reviewed Dockerfile/workflow rather than an untracked local build.

## Deployment boundary

This repository does not own live deployment state. The current Synology deployment is maintained in `nmousouros/nas-infrastructure`; when available, read its `STATE.md` and `stacks/proton-mail/AGENTS.md` before changing cross-repository runtime behavior.

A source change here is not permission to restart, recreate, change permissions on, or expose the live Bridge deployment.

## Supported versions

Until the first stable release, only the current `main` branch and most recent published image are supported.
