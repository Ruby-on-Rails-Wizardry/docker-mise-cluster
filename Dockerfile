# OPTIONAL thin multi-app development image on ubuntu-mise.
#
# Default cluster compose uses **prebuilt ubuntu-mise:dev** directly
# (compose.yml pull_policy: never) — you do **not** need this Dockerfile.
#
# Keep this file only if you need an extra package layer on top of the base.
# Prefer extending ubuntu-mise itself when possible.
#
# Dev contract when used:
#   - mise install at **container runtime** into `/cache` (see bin/docker-app)
#   - Do **not** bake language toolchains into this image at build time
#
# Production apps (Kamal / app Dockerfiles): no mise on boot.

ARG BASE_IMAGE=ubuntu-mise:dev
FROM ${BASE_IMAGE}

# Parent image runs as the non-root user; packages and UID align need root.
USER root

ARG USER=dev
ARG DEV_UID=1000
ARG DEV_GID=1000
ARG POSTGRESQL_VERSION=18
ARG DEBIAN_FRONTEND=noninteractive

# Setup scripts under /docker (kept for cache-friendly layers; not staged via /tmp).
COPY --chmod=755 docker/ /docker/

# Align container user with host bind mounts; ensure /work exists.
# Parent ubuntu-mise may still have ENV HOME=/home/dev — reset after rename.
RUN USER="${USER}" DEV_UID="${DEV_UID}" DEV_GID="${DEV_GID}" /docker/setup-user.sh

# PostgreSQL client + libpq-dev for the Rails pg gem (not in plain ubuntu-mise).
RUN POSTGRESQL_VERSION="${POSTGRESQL_VERSION}" /docker/setup-postgresql.sh

# Project mount / WORKDIR at /work (same contract as ubuntu-mise).
# Keep mise data under /cache (named volume at runtime) so `mise install` in
# bin/docker-app is cached across containers — not baked into the image layer.
# Re-set HOME: base image may bake HOME=/home/dev; USER may be host login.
ENV USER=${USER} \
    HOME=/home/${USER} \
    WORKSPACE=/work \
    MISE_TRUSTED_CONFIG_PATHS=/work \
    CACHE_ROOT=/cache \
    MISE_DATA_DIR=/cache/mise \
    MISE_CACHE_DIR=/cache/mise-cache \
    PATH=/home/${USER}/.local/bin:/cache/mise/shims:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

USER ${USER}
WORKDIR /work

# Keep the ubuntu-mise entrypoint (ensures /cache is writable when that volume is used).
# Language tools: installed at runtime via bin/docker-app (`mise install` + /cache).
CMD ["bash"]
