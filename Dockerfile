# Thin multi-app cluster image on top of a local ubuntu-mise base.
#
# Base (default ubuntu-mise:dev) must already exist on the Docker host:
#   # from docker-mise umbrella
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
#   # or ARG at build: docker build --build-arg BASE_IMAGE=…

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
# MISE_DATA_DIR stays under $HOME so bind-mounting /work does not hide installed tools.
# Re-set HOME/PATH: base image baked HOME=/home/dev; USER may be host login (e.g. rob).
ENV USER=${USER} \
    HOME=/home/${USER} \
    WORKSPACE=/work \
    MISE_TRUSTED_CONFIG_PATHS=/work \
    MISE_DATA_DIR=/home/${USER}/.local/share/mise \
    MISE_CONFIG_DIR=/home/${USER}/.config/mise \
    MISE_CACHE_DIR=/home/${USER}/.cache/mise \
    PATH=/home/${USER}/.local/bin:/home/${USER}/.local/share/mise/shims:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

USER ${USER}
WORKDIR /work

# Pre-install tools from cluster pins (Ruby from Gemfile via idiomatic files).
# The bind mount at runtime replaces this directory; tool installs live in MISE_DATA_DIR.
# Use absolute mise path — do not rely on ~ if HOME was stale in a prior layer.
COPY --chown=${USER}:${USER} mise.toml Gemfile /work/

RUN MISE="/home/${USER}/.local/bin/mise" \
    && test -x "${MISE}" \
    && "${MISE}" trust /work/mise.toml \
    && "${MISE}" install \
    && "${MISE}" reshim \
    && ruby -v \
    && node -v \
    && yarn -v \
    && gem install bundler --no-document

# Keep the ubuntu-mise entrypoint (ensures /cache is writable when that volume is used).
CMD ["bash"]
