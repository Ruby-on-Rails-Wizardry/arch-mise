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

_docker_tty_flags() {
  if [[ -t 0 ]] && [[ -t 1 ]]; then
    printf '%s\n' -it
  else
    printf '%s\n' -i
  fi
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
    ${DOCKER_RUN_OPTS:-} \
    "${IMAGE}" \
    "$@"
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
EOF
}
