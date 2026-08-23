FROM debian:bookworm-slim AS verifier

ARG BRIDGE_VERSION=3.25.0
ARG BRIDGE_REVISION=1

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ca-certificates \
       curl \
       debsig-verify \
       gnupg \
    && rm -rf /var/lib/apt/lists/*

# Download Proton's signing material and package, then fail the build unless
# the official debsig verification succeeds.
RUN set -eux; \
    curl -fsSLo /tmp/bridge_pubkey.gpg https://proton.me/download/bridge/bridge_pubkey.gpg; \
    gpg --batch --dearmor --output /tmp/debsig.gpg /tmp/bridge_pubkey.gpg; \
    mkdir -p /usr/share/debsig/keyrings/E2C75D68E6234B07; \
    mv /tmp/debsig.gpg /usr/share/debsig/keyrings/E2C75D68E6234B07/debsig.gpg; \
    curl -fsSLo /tmp/bridge.pol https://proton.me/download/bridge/bridge.pol; \
    mkdir -p /etc/debsig/policies/E2C75D68E6234B07; \
    cp /tmp/bridge.pol /etc/debsig/policies/E2C75D68E6234B07/bridge.pol; \
    curl -fsSLo /tmp/protonmail-bridge.deb \
      "https://proton.me/download/bridge/protonmail-bridge_${BRIDGE_VERSION}-${BRIDGE_REVISION}_amd64.deb"; \
    debsig-verify /tmp/protonmail-bridge.deb

FROM debian:bookworm-slim AS runtime

ARG BRIDGE_VERSION=3.25.0
ARG BRIDGE_UID=1000
ARG BRIDGE_GID=1000

ENV BRIDGE_HOME=/data

LABEL org.opencontainers.image.title="Proton Mail Bridge (headless Docker wrapper)" \
      org.opencontainers.image.description="Headless Proton Mail Bridge container using Proton's verified Linux package" \
      org.opencontainers.image.source="https://github.com/purplehat93/proton-bridge-docker" \
      org.opencontainers.image.licenses="GPL-3.0-or-later" \
      org.opencontainers.image.version="${BRIDGE_VERSION}"

# Only runtime requirements remain here. Download/verification tooling stays
# behind in the verifier stage and cannot increase the final attack surface.
COPY --from=verifier /tmp/protonmail-bridge.deb /tmp/protonmail-bridge.deb
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ca-certificates \
       gnupg \
       pass \
       /tmp/protonmail-bridge.deb \
    && rm -rf /var/lib/apt/lists/* /tmp/protonmail-bridge.deb \
    && printf 'bridge:x:%s:%s:Proton Bridge:/data:/bin/sh\n' "${BRIDGE_UID}" "${BRIDGE_GID}" >> /etc/passwd \
    && printf 'bridge:x:%s:\n' "${BRIDGE_GID}" >> /etc/group \
    && mkdir -p /data \
    && chown "${BRIDGE_UID}:${BRIDGE_GID}" /data

COPY --chmod=0755 entrypoint.sh /usr/local/bin/proton-bridge-entrypoint

VOLUME ["/data"]
USER ${BRIDGE_UID}:${BRIDGE_GID}

ENTRYPOINT ["/usr/local/bin/proton-bridge-entrypoint"]
CMD ["run"]
