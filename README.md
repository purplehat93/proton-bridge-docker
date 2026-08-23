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

The build is multi-stage: download/signature-verification tools exist only in the verifier stage. The final runtime image contains Bridge and the packages needed for TLS plus the headless GPG/`pass` keychain.

## Persistent state

Mount `/data` persistently. It contains Bridge application state plus the GPG/password-store material used by the headless Linux keychain setup.

Treat this volume as sensitive. Do not commit it or expose it publicly.

The image runs as UID/GID `1000:1000` by default instead of root. If you use a host bind mount, make the directory writable by that identity before starting Bridge, for example:

```bash
mkdir -p data
sudo chown 1000:1000 data
```

For Synology or another host where you want to use an existing UID/GID, build with `BRIDGE_UID` and `BRIDGE_GID` or arrange the bind-mount permissions accordingly.

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

- The final image runs non-root by default.
- Download and `debsig` verification tooling is not retained in the runtime image.
- `.dockerignore` excludes runtime state, environment files, keys, certificates and local secrets from the Docker build context.
- Do not publish Bridge IMAP/SMTP ports to the internet.
- In the intended `proton-mcp` deployment, the MCP container shares Bridge's network namespace so it can use Bridge's loopback-only IMAP/SMTP listeners.
- Never put a Proton password or 2FA secret in this repository, Dockerfile, image, Compose file, or normal environment variables.
- IMAP/SMTP protocol logging is intentionally not enabled because it can contain decrypted mail data.

## CI and image scanning

Every pull request builds the image and must pass:

1. Trivy Docker/IaC configuration scanning.
2. A real container build.
3. A non-root runtime check.
4. A Bridge binary smoke test.
5. A Trivy runtime-image scan that blocks fixed `HIGH` and `CRITICAL` vulnerabilities.

CI also prints the final image size and layer history so image growth is visible during review.

Publishing is a separate job with `packages: write` permission and runs only on trusted pushes after the build/scan job succeeds. Published images include BuildKit SBOM/provenance metadata plus a GitHub artifact attestation.

## Image

After the publishing workflow is enabled on `main`, GitHub Actions publishes:

```text
ghcr.io/purplehat93/proton-bridge:latest
ghcr.io/purplehat93/proton-bridge:sha-<commit>
```

Version tags such as `v0.1.0` publish a matching image tag as well.

## Licensing

Proton Mail Bridge is upstream GPL-3.0-or-later software and remains copyrighted by Proton AG. This repository's wrapper files are intended to be distributed compatibly under GPL-3.0-or-later. See Proton's upstream repository for the corresponding Bridge source and licensing information.
