# Ubuntu LTS development image for multi-app Rails clusters.
# Layout: non-root user home at /home/$USER; project mount at $HOME/wf.
# Tool versions come from mise.toml (Ruby / Node / classic Yarn 1.x).

FROM ubuntu:24.04

# Container login name (default "dev"). Pair with DEV_UID / DEV_GID for bind mounts.
ARG USER=dev
ARG DEV_UID=1000
ARG DEV_GID=1000
# PostgreSQL major for client + libpq-dev (pg gem). Default: current latest stable.
ARG POSTGRESQL_VERSION=18
ARG MISE_VERSION=v2026.5.15
ARG DEBIAN_FRONTEND=noninteractive


# Image/user layout only. Bundler + Yarn project settings live in mounted config.
# HOME / WORKSPACE / mise paths expand from USER at build time.
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    USER=${USER} \
    MISE_DATA_DIR=/home/${USER}/.local/share/mise \
    MISE_CONFIG_DIR=/home/${USER}/.config/mise \
    MISE_CACHE_DIR=/home/${USER}/.cache/mise \
    MISE_RUBY_COMPILE=false \
    PATH=/home/${USER}/.local/bin:/home/${USER}/.local/share/mise/shims:${PATH} \
    HOME=/home/${USER} \
    WORKSPACE=/home/${USER}/wf

# Minimal base + build deps for native gem extensions and common tooling.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        gnupg \
        less \
        libffi-dev \
        libssl-dev \
        libyaml-dev \
        openssh-client \
        pkg-config \
        shared-mime-info \
        sqlite3 \
        libsqlite3-dev \
        sudo \
        tzdata \
        unzip \
        wget \
        zlib1g-dev \
        vim-tiny \
    && rm -rf /var/lib/apt/lists/*

# PostgreSQL client + libpq headers (for Rails pg gem). See docker/setup-postgresql.sh.
COPY docker/setup-postgresql.sh /tmp/setup-postgresql.sh
RUN chmod +x /tmp/setup-postgresql.sh \
    && POSTGRESQL_VERSION="${POSTGRESQL_VERSION}" /tmp/setup-postgresql.sh \
    && rm /tmp/setup-postgresql.sh

# Non-root user (name / UID / GID overridable). See docker/setup-user.sh.
COPY docker/setup-user.sh /tmp/setup-user.sh
RUN chmod +x /tmp/setup-user.sh \
    && USER="${USER}" DEV_UID="${DEV_UID}" DEV_GID="${DEV_GID}" /tmp/setup-user.sh \
    && rm /tmp/setup-user.sh

USER ${USER}

WORKDIR /home/${USER}/wf

# Install mise (https://mise.jdx.dev) for the image user.
RUN curl -fsSL https://mise.run | MISE_VERSION="${MISE_VERSION}" sh \
    && echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc \
    && echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bash_profile

# Copy only version pins first for better layer caching.
COPY --chown=${USER}:${USER} mise.toml /home/${USER}/wf/mise.toml

# Trust project config and install pinned Ruby + Node + Yarn 1.
RUN ~/.local/bin/mise trust /home/${USER}/wf/mise.toml \
    && ~/.local/bin/mise install \
    && ~/.local/bin/mise reshim \
    && ruby -v \
    && node -v \
    && yarn -v \
    && gem install bundler --no-document

# Default to an interactive shell; compose overrides command per service.
CMD ["bash"]
