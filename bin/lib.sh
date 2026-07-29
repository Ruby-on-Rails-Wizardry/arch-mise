#!/usr/bin/env bash
# Shared helpers for host-side bin/* and Taskfile recipes.
# shellcheck disable=SC2034

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLAVOR="${FLAVOR:-$(basename "${ROOT}")}"
IMAGE="${IMAGE:-${FLAVOR}:dev}"
CACHE_VOLUME="${CACHE_VOLUME:-${FLAVOR}-cache}"
IMAGE_USER="${IMAGE_USER:-dev}"
DEV_UID="${DEV_UID:-$(id -u)}"
DEV_GID="${DEV_GID:-$(id -g)}"
# Project to mount at /work (default: caller's current directory).
PROJECT="${PROJECT:-${PWD}}"
CACHE_ROOT="${CACHE_ROOT:-/cache}"

log() {
  printf '%s: %s\n' "${FLAVOR}" "$*" >&2
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

ensure_image() {
  require_docker
  if ! image_exists; then
    log "image ${IMAGE} missing — building"
    "${ROOT}/bin/build"
  fi
}

ensure_cache_volume() {
  require_docker
  if ! docker volume inspect "${CACHE_VOLUME}" >/dev/null 2>&1; then
    log "creating volume ${CACHE_VOLUME}"
    docker volume create "${CACHE_VOLUME}" >/dev/null
  fi
}

# Docker -i/-t flags for this host process.
# Without -t, bash is non-interactive (no PS1) — classic "bin/shell has no prompt".
# DOCKER_FORCE_TTY=1 always allocates a TTY (used by bin/shell). Docker errors
# clearly if stdin is not a terminal; prefer that over a silent non-interactive shell.
_docker_tty_flags() {
  local -a flags=(-i)
  if [[ "${DOCKER_FORCE_TTY:-0}" == "1" ]] || [[ -t 0 ]]; then
    flags+=(-t)
  fi
  # One flag per line for mapfile; avoid `printf … -it` (some printfs parse as options).
  printf '%s\n' "${flags[@]}"
}

# Supported host contexts for bin/* (always run from a Unix shell):
#   1) native Linux
#   2) native macOS (Docker Desktop or similar)
#   3) Windows + Docker Desktop, project accessed **inside WSL** (Linux distro)
# Not supported: native Windows shells / project only on /mnt/c outside WSL.
host_kind() {
  local uname_s
  uname_s="$(uname -s 2>/dev/null || printf 'unknown')"
  case "${uname_s}" in
    Darwin)
      printf 'macos\n'
      ;;
    Linux)
      # WSL1/WSL2: env, interop, or kernel version string
      if [[ -n "${WSL_DISTRO_NAME:-}" ]] \
        || [[ -e /proc/sys/fs/binfmt_misc/WSLInterop ]] \
        || grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
        printf 'wsl\n'
      else
        printf 'linux\n'
      fi
      ;;
    *)
      printf 'unknown\n'
      ;;
  esac
}

# Resolve /etc/localtime → IANA zone (Linux, macOS, WSL). Avoid GNU-only readlink -f.
_host_timezone_from_localtime() {
  local target=""
  if [[ ! -e /etc/localtime ]]; then
    return 1
  fi
  if command -v realpath >/dev/null 2>&1; then
    target="$(realpath /etc/localtime 2>/dev/null || true)"
  fi
  if [[ -z "${target}" ]]; then
    # GNU readlink -f (Linux); macOS readlink has no -f
    target="$(readlink -f /etc/localtime 2>/dev/null || true)"
  fi
  if [[ -z "${target}" ]] && [[ -L /etc/localtime ]]; then
    target="$(readlink /etc/localtime 2>/dev/null || true)"
    if [[ -n "${target}" && "${target}" != /* ]]; then
      target="/etc/${target}"
    fi
  fi
  if [[ -z "${target}" ]] && command -v python3 >/dev/null 2>&1; then
    target="$(
      python3 -c 'import os; print(os.path.realpath("/etc/localtime"))' 2>/dev/null || true
    )"
  fi
  # Linux: .../zoneinfo/America/Denver
  # macOS: .../zoneinfo/America/Denver or /var/db/timezone/zoneinfo/...
  if [[ "${target}" == *zoneinfo/* ]]; then
    printf '%s\n' "${target##*zoneinfo/}"
    return 0
  fi
  return 1
}

# IANA zone for containers (matches host when possible). Honors explicit TZ=.
# Images already ship tzdata; glibc/musl honor TZ without rewriting /etc/localtime.
host_timezone() {
  local z
  if [[ -n "${TZ:-}" ]]; then
    printf '%s\n' "${TZ}"
    return 0
  fi
  # Debian/Ubuntu/WSL often ship this file
  if [[ -r /etc/timezone ]]; then
    z="$(tr -d '[:space:]' </etc/timezone 2>/dev/null || true)"
    if [[ -n "${z}" ]]; then
      printf '%s\n' "${z}"
      return 0
    fi
  fi
  # systemd (native Linux, many WSL2 distros)
  if command -v timedatectl >/dev/null 2>&1; then
    z="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
    if [[ -n "${z}" ]]; then
      printf '%s\n' "${z}"
      return 0
    fi
  fi
  if z="$(_host_timezone_from_localtime)"; then
    printf '%s\n' "${z}"
    return 0
  fi
  printf 'UTC\n'
}

# Run a command in the image with project + cache mounts.
run_in_image() {
  ensure_image
  ensure_cache_volume

  local -a tty
  mapfile -t tty < <(_docker_tty_flags)
  local tz
  tz="$(host_timezone)"

  # shellcheck disable=SC2086
  docker run --rm \
    "${tty[@]}" \
    -v "${PROJECT}:/work:cached" \
    -w /work \
    -v "${CACHE_VOLUME}:/cache" \
    -e "USER=${IMAGE_USER}" \
    -e "HOME=/home/${IMAGE_USER}" \
    -e "CACHE_ROOT=${CACHE_ROOT}" \
    -e "TZ=${tz}" \
    -e "TERM=${TERM:-xterm-256color}" \
    ${DOCKER_RUN_OPTS:-} \
    "${IMAGE}" \
    "$@"
}

# Ensure the sample_app git submodule is checked out (Gemfile present).
# No-op when .gitmodules has no sample_app entry.
ensure_sample_app() {
  local gm="${ROOT}/.gitmodules"
  local dir="${ROOT}/sample_app"
  if [[ ! -f "${gm}" ]] || ! grep -q 'path = sample_app' "${gm}" 2>/dev/null; then
    return 0
  fi
  if [[ -f "${dir}/Gemfile" ]]; then
    return 0
  fi
  if [[ ! -d "${ROOT}/.git" ]] && [[ ! -f "${ROOT}/.git" ]]; then
    log "warning: sample_app missing and not a git checkout — clone with --recurse-submodules"
    return 1
  fi
  log "initializing sample_app submodule"
  if ! git -C "${ROOT}" submodule update --init --recursive sample_app; then
    log "error: could not init sample_app submodule (git submodule update --init sample_app)"
    return 1
  fi
  if [[ ! -f "${dir}/Gemfile" ]]; then
    log "error: sample_app still missing Gemfile after submodule init"
    return 1
  fi
}

print_config() {
  cat <<EOF
FLAVOR=${FLAVOR}
IMAGE=${IMAGE}
CACHE_VOLUME=${CACHE_VOLUME}
IMAGE_USER=${IMAGE_USER}
DEV_UID=${DEV_UID}
DEV_GID=${DEV_GID}
PROJECT=${PROJECT}
TZ=$(host_timezone)
HOST_KIND=$(host_kind)
ROOT=${ROOT}
SAMPLE_APP=${ROOT}/sample_app
EOF
}
