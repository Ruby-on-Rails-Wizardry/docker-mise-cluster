#!/usr/bin/env bash
# Install PostgreSQL client tools and libpq development headers (for the pg gem).
#
# Uses the official PGDG apt repository so the requested major version is
# available on Ubuntu LTS (distro packages lag behind).
#
# Expected environment (Docker build ARGs):
#   POSTGRESQL_VERSION  major version (default: 18 — current latest stable)
#
# Installs:
#   postgresql-client-${POSTGRESQL_VERSION}  — psql and related CLI tools
#   libpq-dev                               — headers/libs for native pg gem builds

set -euo pipefail

POSTGRESQL_VERSION="${POSTGRESQL_VERSION:-18}"
PGDG_KEYRING="/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc"
PGDG_LIST="/etc/apt/sources.list.d/pgdg.list"
export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

log() {
  printf 'setup-postgresql: %s\n' "$*"
}

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "setup-postgresql: must run as root" >&2
    exit 1
  fi
}

ubuntu_codename() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf '%s\n' "${VERSION_CODENAME:?VERSION_CODENAME missing in /etc/os-release}"
    return
  fi
  if command -v lsb_release >/dev/null 2>&1; then
    lsb_release -cs
    return
  fi
  echo "setup-postgresql: cannot determine Ubuntu codename" >&2
  exit 1
}

add_pgdg_repo() {
  local codename
  codename="$(ubuntu_codename)"

  log "ensuring ca-certificates curl gnupg for PGDG apt source"
  apt-get update
  apt-get install -y --no-install-recommends ca-certificates curl gnupg

  install -d -m 0755 "$(dirname "${PGDG_KEYRING}")"

  if [[ ! -f "${PGDG_KEYRING}" ]]; then
    log "fetching PGDG signing key → ${PGDG_KEYRING}"
    curl -fsSL -o "${PGDG_KEYRING}" https://www.postgresql.org/media/keys/ACCC4CF8.asc
  fi

  log "configuring PGDG apt source for ${codename}-pgdg"
  cat >"${PGDG_LIST}" <<EOF
deb [signed-by=${PGDG_KEYRING}] https://apt.postgresql.org/pub/repos/apt ${codename}-pgdg main
EOF
}

install_client_and_dev() {
  local client_pkg="postgresql-client-${POSTGRESQL_VERSION}"

  log "installing ${client_pkg} and libpq-dev"
  apt-get update
  apt-get install -y --no-install-recommends \
    "${client_pkg}" \
    libpq-dev

  log "psql: $(psql --version 2>/dev/null || echo 'not on PATH')"
  if pkg-config --exists libpq 2>/dev/null; then
    log "libpq: $(pkg-config --modversion libpq)"
  else
    log "libpq-dev installed (pkg-config libpq may need PATH later)"
  fi
}

main() {
  require_root

  if ! [[ "${POSTGRESQL_VERSION}" =~ ^[0-9]+$ ]]; then
    echo "setup-postgresql: POSTGRESQL_VERSION must be a major number (got: ${POSTGRESQL_VERSION})" >&2
    exit 1
  fi

  log "POSTGRESQL_VERSION=${POSTGRESQL_VERSION}"
  add_pgdg_repo
  install_client_and_dev
  # Leave /var/lib/apt/lists so later apt operations can reuse the index.
  log "done"
}

main "$@"
