#!/usr/bin/env bash
# Shared helpers for cluster host UX (bin/* / Taskfile / mise tasks).
# shellcheck disable=SC2034

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER="${CLUSTER:-$(basename "${ROOT}")}"
FLAVOR_BASE="${FLAVOR_BASE:-ubuntu-mise}"
IMAGE="${IMAGE:-${FLAVOR_BASE}:dev}"
CACHE_VOLUME="${CACHE_VOLUME:-${FLAVOR_BASE}-cache}"
# Compose project: leave COMPOSE_PROJECT_NAME unset so Docker uses the directory
# name (basename of project-directory). Export only if the operator set it.

load_dotenv_if_unset() {
  local file=$1
  local line key val
  [[ -f "${file}" ]] || return 0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%$'\r'}"
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    [[ "${line}" =~ ^[[:space:]]*$ ]] && continue
    [[ "${line}" == *=* ]] || continue
    key="${line%%=*}"
    val="${line#*=}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    [[ "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    if declare -p "${key}" &>/dev/null; then
      continue
    fi
    if [[ "${val}" =~ ^\"(.*)\"$ ]]; then
      val="${BASH_REMATCH[1]}"
    elif [[ "${val}" =~ ^\'(.*)\'$ ]]; then
      val="${BASH_REMATCH[1]}"
    fi
    export "${key}=${val}"
  done <"${file}"
}

load_dotenv_if_unset "${ROOT}/.mise.env"
load_dotenv_if_unset "${ROOT}/.mise.env.local"

if [[ -z "${USER:-}" ]]; then
  USER="$(id -un 2>/dev/null || printf 'dev')"
  export USER
fi
if [[ -z "${SHELL:-}" ]]; then
  SHELL="/bin/bash"
  export SHELL
fi
export DEV_UID="${DEV_UID:-$(id -u)}"
export DEV_GID="${DEV_GID:-$(id -g)}"
# Match host login by default (same as ubuntu-mise / ubuntu-sample).
# Override in .mise.env.local only if the base image was built for another user.
export IMAGE_USER="${IMAGE_USER:-${USER}}"
PROJECT="${PROJECT:-${ROOT}}"
CACHE_ROOT="${CACHE_ROOT:-/cache}"
: "${POSTGRESQL_VERSION:=}"
REDIS_VERSION="${REDIS_VERSION:-8}"
# Effective Compose project name (Docker default = directory basename).
COMPOSE_PROJECT_EFFECTIVE="${COMPOSE_PROJECT_NAME:-${CLUSTER}}"

log() {
  printf '%s: %s\n' "${CLUSTER}" "$*" >&2
}

die() {
  log "error: $*"
  exit 1
}

require_docker() {
  command -v docker >/dev/null 2>&1 || die "docker not found on PATH"
  docker info >/dev/null 2>&1 || die "docker daemon not reachable"
}

image_exists() {
  docker image inspect "${IMAGE}" >/dev/null 2>&1
}

find_ubuntu_mise_root() {
  if [[ -n "${UBUNTU_MISE_ROOT:-}" && -f "${UBUNTU_MISE_ROOT}/Dockerfile" ]]; then
    (cd "${UBUNTU_MISE_ROOT}" && pwd)
    return 0
  fi
  if [[ -f "${ROOT}/../ubuntu-mise/Dockerfile" ]]; then
    (cd "${ROOT}/../ubuntu-mise" && pwd)
    return 0
  fi
  return 1
}

ensure_image() {
  require_docker
  if image_exists; then
    return 0
  fi
  local sibling=""
  if sibling="$(find_ubuntu_mise_root)"; then
    log "image ${IMAGE} missing — building via ${sibling}"
    (
      cd "${sibling}"
      export IMAGE
      export POSTGRESQL_VERSION
      export DEV_UID DEV_GID
      export IMAGE_USER
      if [[ -x ./bin/build ]]; then
        ./bin/build
      else
        die "${sibling}/bin/build not executable"
      fi
    )
    return 0
  fi
  die "image ${IMAGE} missing — build base: (cd ../ubuntu-mise && task build) or set UBUNTU_MISE_ROOT"
}

ensure_cache_volume() {
  require_docker
  if ! docker volume inspect "${CACHE_VOLUME}" >/dev/null 2>&1; then
    log "creating volume ${CACHE_VOLUME}"
    docker volume create "${CACHE_VOLUME}" >/dev/null
  fi
}

host_timezone() {
  local z
  if [[ -n "${TZ:-}" ]]; then
    printf '%s\n' "${TZ}"
    return 0
  fi
  if [[ -r /etc/timezone ]]; then
    z="$(tr -d '[:space:]' </etc/timezone 2>/dev/null || true)"
    [[ -n "${z}" ]] && { printf '%s\n' "${z}"; return 0; }
  fi
  if command -v timedatectl >/dev/null 2>&1; then
    z="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
    [[ -n "${z}" ]] && { printf '%s\n' "${z}"; return 0; }
  fi
  printf 'UTC\n'
}

export TZ="${TZ:-$(host_timezone)}"

print_config() {
  cat <<EOF
CLUSTER=${CLUSTER}
FLAVOR_BASE=${FLAVOR_BASE}
IMAGE=${IMAGE}
CACHE_VOLUME=${CACHE_VOLUME}
IMAGE_USER=${IMAGE_USER}
DEV_UID=${DEV_UID}
DEV_GID=${DEV_GID}
USER=${USER}
SHELL=${SHELL}
PROJECT=${PROJECT}
POSTGRESQL_VERSION=${POSTGRESQL_VERSION:-}
REDIS_VERSION=${REDIS_VERSION}
TZ=${TZ}
ROOT=${ROOT}
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-}
COMPOSE_PROJECT_EFFECTIVE=${COMPOSE_PROJECT_EFFECTIVE}
APPS=$( [[ -x "${ROOT}/bin/apps" ]] && "${ROOT}/bin/apps" names | tr '\n' ' ' || echo "fred ron harry george" )
EOF
}
