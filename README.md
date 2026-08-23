# proton-bridge-docker

A small, auditable Docker wrapper around the official Proton Mail Bridge Linux package for headless/self-hosted use.

This repository does **not** reimplement Proton Mail Bridge. The image downloads Proton's official `amd64` Debian package during build, verifies it with Proton's published `debsig` key/policy, and runs Bridge in either CLI setup mode or non-interactive service mode.

## Intended use

This image is designed to run next to [`purplehat93/proton-mcp`](https://github.com/purplehat93/proton-mcp) on an x86_64 NAS/home server.

```text
MCP client
    |
    v
proton-mcp
    |
    | localhost IMAP
    v
proton-bridge
    |
    v
Proton Mail
```

The two applications are separate repositories, separate images, and separate release lifecycles. They can still be deployed together in one Docker Compose stack.

## Supported architecture

Currently: `linux/amd64` only.

## Build

```bash
docker build -t proton-bridge .
```

The default Bridge version is pinned in the Dockerfile. It can be overridden deliberately:

```bash
docker build \
  --build-arg BRIDGE_VERSION=3.25.0 \
  --build-arg BRIDGE_REVISION=1 \
  -t proton-bridge .
```

## Persistent state

Mount `/data` persistently. It contains Bridge application state plus the GPG/password-store material used by the headless Linux keychain setup.

Treat this volume as sensitive. Do not commit it or expose it publicly.

## First-time setup

```bash
docker run --rm -it \
  -v ./data:/data \
  proton-bridge init
```

This initializes the local `pass` keychain and opens Proton Bridge's official CLI. Authenticate there. Your Proton account password is not baked into the image or stored in this repository.

## Normal operation

```bash
docker run -d \
  --name proton-bridge \
  -v ./data:/data \
  proton-bridge
```

Normal startup uses Proton Bridge's `--noninteractive` mode and reuses persisted authentication/state.

For administrative access later:

```bash
docker exec -it proton-bridge proton-bridge-entrypoint cli
```

## Security model

- Do not publish Bridge IMAP/SMTP ports to the internet.
- In the intended `proton-mcp` deployment, the MCP container shares Bridge's network namespace so it can use Bridge's loopback-only IMAP/SMTP listeners.
- Never put a Proton password or 2FA secret in this repository, Dockerfile, image, Compose file, or normal environment variables.
- IMAP/SMTP protocol logging is intentionally not enabled because it can contain decrypted mail data.

## Image

GitHub Actions will publish:

```text
ghcr.io/purplehat93/proton-bridge:latest
```

and version-tagged images once releases/tags are used.

## Licensing

Proton Mail Bridge is upstream GPL-3.0-or-later software and remains copyrighted by Proton AG. This repository's wrapper files are intended to be distributed compatibly under GPL-3.0-or-later. See Proton's upstream repository for the corresponding Bridge source and licensing information.
