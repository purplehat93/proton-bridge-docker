FROM golang:1.26.2-bookworm AS builder

ARG BRIDGE_VERSION=3.25.0
ARG BRIDGE_COMMIT=f1f599e97167265cb0d10ad3d169269c324d9cc7

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ca-certificates \
       gcc \
       git \
       libcbor-dev \
       libfido2-dev \
       libglvnd-dev \
       libsecret-1-dev \
       libssl-dev \
       make \
       pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Build the exact, immutable commit behind Proton Bridge v3.25.0. The release
# commit is signed/verified upstream; pinning its full SHA prevents tag movement
# from silently changing what this image compiles.
RUN set -eux; \
    git init; \
    git remote add origin https://github.com/ProtonMail/proton-bridge.git; \
    git fetch --depth 1 origin "${BRIDGE_COMMIT}"; \
    git checkout --detach FETCH_HEAD; \
    test "$(git rev-parse HEAD)" = "${BRIDGE_COMMIT}"; \
    make build-nogui BRIDGE_APP_VERSION="${BRIDGE_VERSION}"; \
    test -x /src/bridge; \
    /src/bridge --version; \
    ldd /src/bridge

FROM debian:bookworm-slim AS runtime

ARG BRIDGE_VERSION=3.25.0
ARG BRIDGE_COMMIT=f1f599e97167265cb0d10ad3d169269c324d9cc7
ARG BRIDGE_UID=1000
ARG BRIDGE_GID=1000

ENV BRIDGE_HOME=/data

LABEL org.opencontainers.image.title="Proton Mail Bridge (headless Docker build)" \
      org.opencontainers.image.description="Headless Proton Mail Bridge compiled from Proton's official source" \
      org.opencontainers.image.source="https://github.com/purplehat93/proton-bridge-docker" \
      org.opencontainers.image.licenses="GPL-3.0-or-later" \
      org.opencontainers.image.version="${BRIDGE_VERSION}" \
      org.opencontainers.image.revision="${BRIDGE_COMMIT}"

# Runtime-only libraries for the headless Go/CGO binary plus pass/GPG for the
# supported Linux keychain. No compiler, Git, Qt, X11, audio stack, or package
# verification tooling is retained in the final image.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ca-certificates \
       libcbor0.8 \
       libfido2-1 \
       libsecret-1-0 \
       libssl3 \
       pass \
    && rm -rf /var/lib/apt/lists/* \
    && printf 'bridge:x:%s:%s:Proton Bridge:/data:/bin/sh\n' "${BRIDGE_UID}" "${BRIDGE_GID}" >> /etc/passwd \
    && printf 'bridge:x:%s:\n' "${BRIDGE_GID}" >> /etc/group \
    && mkdir -p /data \
    && chown "${BRIDGE_UID}:${BRIDGE_GID}" /data

COPY --from=builder /src/bridge /usr/local/bin/bridge
COPY --chmod=0755 entrypoint.sh /usr/local/bin/proton-bridge-entrypoint

VOLUME ["/data"]
USER ${BRIDGE_UID}:${BRIDGE_GID}

ENTRYPOINT ["/usr/local/bin/proton-bridge-entrypoint"]
CMD ["run"]
