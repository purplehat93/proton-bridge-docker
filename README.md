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

The current Synology deployment is maintained separately in `nmousouros/nas-infrastructure`. When that repository is available in the same workspace, its `STATE.md` is the source of truth for changing runtime facts such as deployment status, live ports, Bridge sync state, and real-mailbox validation. Do not duplicate those changing facts here.

## Supported architecture

Currently: `linux/amd64` only.

## Build

```bash
docker build -t proton-bridge .
```

The Dockerfile pins both the human-readable Bridge version and the immutable upstream release commit. The current build is Proton Mail Bridge 3.26.0 from:

```text
726f7aa62ac993afc67ec566b36243d1c2bafa3d
```

The multi-stage build uses Proton's documented headless target:

```bash
make build-nogui BRIDGE_APP_VERSION=3.26.0
```

Compilers, Git, development headers, Qt, X11, graphics/audio libraries and the desktop launcher are not copied into the final runtime image.

## Persistent state

Mount `/data` persistently. It contains Bridge application state plus the GPG/password-store material used by the headless Linux keychain setup.

Treat this volume as sensitive. Do not commit it or expose it publicly.

The image runs as UID/GID `1000:1000` by default instead of root. If you use a host bind mount, make the directory writable by that identity before first use, for example:

```bash
mkdir -p data
sudo chown 1000:1000 data
```

Do not re-run ownership preparation blindly against an existing live Bridge state. For Synology or another host where a different identity is required, build with `BRIDGE_UID` and `BRIDGE_GID` or arrange the bind-mount permissions deliberately.

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

Normal startup invokes the headless Bridge binary with `--noninteractive` and reuses persisted authentication/state. Once the account has been bootstrapped successfully, normal startup should not require an interactive CLI login.

## Administrative CLI access

`proton-bridge-entrypoint cli` starts another Bridge process in CLI mode. Do **not** run that command with `docker exec` inside an already-running Bridge container; the second Bridge process can conflict with the running instance's application lock.

For a standalone Docker deployment, stop the normal Bridge container and run a one-shot CLI container against the same persistent `/data`, then start normal service again. For example, adapting the path to your deployment:

```bash
docker stop proton-bridge

docker run --rm -it \
  -v /path/to/persistent/bridge-data:/data \
  proton-bridge cli

docker start proton-bridge
```

For the Synology Compose deployment, use the exact one-shot CLI procedure documented in `nmousouros/nas-infrastructure/stacks/proton-mail/AGENTS.md` rather than inventing a second process inside the live container.

## Security model

- The final image runs non-root by default.
- Proton source is pinned to an immutable release commit rather than a mutable tag alone.
- The runtime contains the upstream `bridge` binary, not the GUI launcher/distribution package.
- Build compilers, Git, headers and other build tooling remain in the builder stage only.
- `.dockerignore` excludes runtime state, environment files, keys, certificates and local secrets from the Docker build context.
- Do not publish Bridge IMAP/SMTP ports to the public internet.
- In the intended `proton-mcp` deployment, the MCP container shares Bridge's network namespace so it can use Bridge's loopback-only IMAP/SMTP listeners without publishing them to the LAN.
- Never put a Proton password, 2FA secret, Bridge-generated password, or persisted Bridge state in this repository, Dockerfile, image, Compose file, or normal environment variables.
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

Trusted pushes publish:

```text
ghcr.io/purplehat93/proton-bridge:latest
ghcr.io/purplehat93/proton-bridge:sha-<commit>
```

Version tags such as `v0.1.0` publish a matching image tag as well.

## Documentation for agents

Read [`AGENTS.md`](AGENTS.md) before changing build/runtime behavior and [`SECURITY.md`](SECURITY.md) before changing credentials, networking, persistent state, source verification, or logging.

## Licensing

Proton Mail Bridge is upstream GPL-3.0-or-later software and remains copyrighted by Proton AG. This repository's wrapper files are intended to be distributed compatibly under GPL-3.0-or-later. The image is built directly from the public Proton source commit identified above, so the corresponding upstream source remains unambiguous and available from Proton's repository.
