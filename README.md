# proton-bridge-docker

A small, auditable Docker build of Proton Mail Bridge for headless/self-hosted use.

This repository does **not** reimplement Proton Mail Bridge. It compiles Proton's official source using the upstream-supported `make build-nogui` target and copies only the resulting headless `bridge` binary into the runtime image.

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

The Dockerfile pins both the human-readable Bridge version and the immutable upstream release commit. For Bridge 3.25.0 that source commit is:

```text
f1f599e97167265cb0d10ad3d169269c324d9cc7
```

The multi-stage build uses Proton's documented headless target:

```bash
make build-nogui
```

Compilers, Git, development headers, Qt, X11, graphics/audio libraries and the desktop launcher are not copied into the final runtime image.

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

Normal startup invokes the headless Bridge binary with `--noninteractive` and reuses persisted authentication/state.

For administrative access later:

```bash
docker exec -it proton-bridge proton-bridge-entrypoint cli
```

## Security model

- The final image runs non-root by default.
- Proton source is pinned to an immutable release commit rather than a mutable tag alone.
- The runtime contains the upstream `bridge` binary, not the GUI launcher/distribution package.
- Build compilers, Git, headers and other build tooling remain in the builder stage only.
- `.dockerignore` excludes runtime state, environment files, keys, certificates and local secrets from the Docker build context.
- Do not publish Bridge IMAP/SMTP ports to the internet.
- In the intended `proton-mcp` deployment, the MCP container shares Bridge's network namespace so it can use Bridge's loopback-only IMAP/SMTP listeners.
- Never put a Proton password or 2FA secret in this repository, Dockerfile, image, Compose file, or normal environment variables.
- IMAP/SMTP protocol logging is intentionally not enabled because it can contain decrypted mail data.

## CI and image scanning

Every pull request builds the image and must pass:

1. Trivy Docker/IaC configuration scanning.
2. A real source build of the pinned Proton Bridge commit.
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

Proton Mail Bridge is upstream GPL-3.0-or-later software and remains copyrighted by Proton AG. This repository's wrapper files are intended to be distributed compatibly under GPL-3.0-or-later. The image is built directly from the public Proton source commit identified above, so the corresponding upstream source remains unambiguous and available from Proton's repository.
