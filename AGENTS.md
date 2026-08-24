# AGENTS.md

Keep this repository focused on building and packaging the official headless Proton Mail Bridge.

## Before editing

1. Read `README.md` for the build/runtime model.
2. Read `SECURITY.md` before touching credentials, network exposure, persistent state, source verification, or logging.
3. Inspect `Dockerfile` and `entrypoint.sh`; do not infer their behavior from old documentation.
4. If `nmousouros/nas-infrastructure` is available in the same workspace, read its `STATE.md` and `stacks/proton-mail/AGENTS.md` for the current live deployment state.
5. If `purplehat93/proton-mcp` is available, read its `AGENTS.md`, `ARCHITECTURE.md`, and `SECURITY.md` before changing cross-repository integration behavior.

## Repository boundary

This repository owns only the Proton Bridge image build and its entrypoint behavior.

Related repositories:

- `purplehat93/proton-mcp` — MCP server consuming Bridge's local IMAP interface.
- `nmousouros/nas-infrastructure` — live Synology Compose deployment and runtime handoff.

Do not duplicate changing deployment facts here. Runtime ports, sync state, mailbox statistics, and live validation results belong in the deployment repository.

## Invariants

- Build Proton Mail Bridge from an explicitly pinned upstream source version and immutable commit.
- Keep the final runtime image minimal and non-root.
- Treat `/data` as sensitive persistent state; it contains Bridge state and local GPG/password-store material.
- Never commit Proton credentials, Bridge-generated credentials, keyrings, vault/state, mailbox data, tokens, logs, or populated environment files.
- Do not expose Bridge IMAP/SMTP directly to the public internet. In the intended MCP deployment they remain loopback-only inside the shared network namespace.
- Do not enable protocol-level IMAP/SMTP logging in normal operation; decrypted mail data may appear in logs.
- Do not replace the official Bridge protocol/crypto implementation with custom logic in this repository.
- A source/documentation change is not permission to restart or alter the live NAS deployment.

## CLI / process safety

`entrypoint.sh cli` starts a Bridge CLI process. Do not run it inside an already-running Bridge container as a second Bridge instance; Bridge uses a process/application lock.

For an existing deployment, stop the running Bridge service and use a one-shot container with the same persistent `/data`, then restore normal service. In the Synology deployment, follow the exact procedure documented in `nas-infrastructure/stacks/proton-mail/AGENTS.md`.

Normal operation uses `bridge --noninteractive` and should reuse persisted authentication/state without requiring an interactive CLI login.

## Validation

For Dockerfile or entrypoint changes, at minimum verify:

- the image builds from the pinned source commit;
- `bridge --version` reports the intended version;
- the runtime container remains non-root;
- normal entrypoint mode starts `bridge --noninteractive`;
- CLI mode starts `bridge --cli` only when intentionally invoked;
- security/image scanning workflows remain green.
