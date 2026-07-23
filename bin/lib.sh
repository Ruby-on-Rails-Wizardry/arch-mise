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

# Run a command in the image with project + cache mounts.
run_in_image() {
  ensure_image
  ensure_cache_volume

  local -a tty
  mapfile -t tty < <(_docker_tty_flags)

  # shellcheck disable=SC2086
  docker run --rm \
    "${tty[@]}" \
    -v "${PROJECT}:/work:cached" \
    -w /work \
    -v "${CACHE_VOLUME}:/cache" \
    -e "USER=${IMAGE_USER}" \
    -e "HOME=/home/${IMAGE_USER}" \
    -e "CACHE_ROOT=${CACHE_ROOT}" \
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
ROOT=${ROOT}
SAMPLE_APP=${ROOT}/sample_app
EOF
}
