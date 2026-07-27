# Thin multi-app **development** image on top of a local ubuntu-mise base.
#
# Dev contract (locked):
#   - mise is present in the base image
#   - `mise install` runs at **container runtime** (see bin/docker-app), using
#     the shared `/cache` volume for tool installs (MISE_DATA_DIR=/cache/mise)
#   - Do **not** bake language toolchains into this image at build time
#
# Production apps (Kamal / app Dockerfiles): if they use mise at all,
# `mise install` runs only at **image build** — never on boot.
#
# Base (default ubuntu-mise:dev) must already exist on the Docker host:
#   task ubuntu:build
#   # or
#   (cd ../ubuntu-mise && ./bin/build)
#
# Then:
#   bin/setup --docker-build
#   # or
#   bin/compose build
#
# Override the parent with:
#   BASE_IMAGE=my/ubuntu-mise:dev bin/compose build

ARG BASE_IMAGE=ubuntu-mise:dev
FROM ${BASE_IMAGE}

# Parent image runs as the non-root user; packages and UID align need root.
USER root

ARG USER=dev
ARG DEV_UID=1000
ARG DEV_GID=1000
ARG POSTGRESQL_VERSION=18
ARG DEBIAN_FRONTEND=noninteractive

# Align container user with host bind mounts; ensure /work exists.
# Parent ubuntu-mise may still have ENV HOME=/home/dev — reset after rename.
COPY docker/setup-user.sh /tmp/setup-user.sh
RUN chmod +x /tmp/setup-user.sh \
    && USER="${USER}" DEV_UID="${DEV_UID}" DEV_GID="${DEV_GID}" /tmp/setup-user.sh \
    && rm /tmp/setup-user.sh

# PostgreSQL client + libpq-dev for the Rails pg gem (not in plain ubuntu-mise).
COPY docker/setup-postgresql.sh /tmp/setup-postgresql.sh
RUN chmod +x /tmp/setup-postgresql.sh \
    && POSTGRESQL_VERSION="${POSTGRESQL_VERSION}" /tmp/setup-postgresql.sh \
    && rm /tmp/setup-postgresql.sh

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
