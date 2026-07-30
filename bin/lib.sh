#!/usr/bin/env bash
# Shared helpers for host-side bin/* and Taskfile recipes.
# shellcheck disable=SC2034

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLAVOR="${FLAVOR:-$(basename "${ROOT}")}"
IMAGE="${IMAGE:-${FLAVOR}:dev}"
CACHE_VOLUME="${CACHE_VOLUME:-${FLAVOR}-cache}"

# Load committed .mise.env (and optional gitignored .mise.env.local) without
# clobbering variables already set in the shell. Same file mise.toml loads via
# env._.file so `mise activate` / `task` stay consistent with bin/*.
load_dotenv_if_unset() {
  local file=$1
  local line key val
  [[ -f "${file}" ]] || return 0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    # strip CR, comments, blanks
    line="${line%$'\r'}"
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    [[ "${line}" =~ ^[[:space:]]*$ ]] && continue
    [[ "${line}" == *=* ]] || continue
    key="${line%%=*}"
    val="${line#*=}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    [[ "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    # already set in environment (including empty export FOO=)?
    if declare -p "${key}" &>/dev/null; then
      continue
    fi
    # strip one layer of matching quotes
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

# Same host identity mise exports via bin/mise-host-env.sh (keep bin/* working
# without mise activate). Fill gaps only — never invent over an existing export.
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
export IMAGE_USER="${IMAGE_USER:-${USER}}"
# Project to mount at /work (default: caller's current directory).
PROJECT="${PROJECT:-${PWD}}"
CACHE_ROOT="${CACHE_ROOT:-/cache}"
# From .mise.env by default (currently 18); empty skips client install in Dockerfile.
: "${POSTGRESQL_VERSION:=}"

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

# Ensure TZ is exported for compose/build (mise-host-env.sh does the same).
export TZ="${TZ:-$(host_timezone)}"

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

# Sibling sample app next to this flavor under the docker-mise umbrella:
#   ubuntu-mise → ../ubuntu-sample  (same pattern for alpine/arch)
# Override with SAMPLE_APP or SAMPLE_APP_DIR.
default_sample_app_dir() {
  local parent name
  parent="$(cd "${ROOT}/.." && pwd)"
  name="${FLAVOR%-mise}-sample"
  printf '%s\n' "${parent}/${name}"
}

SAMPLE_APP="${SAMPLE_APP:-${SAMPLE_APP_DIR:-$(default_sample_app_dir)}}"

# Ensure the sibling sample app is present (umbrella submodule: ubuntu-sample, …).
ensure_sample_app() {
  local dir="${SAMPLE_APP}"
  local parent name ugm

  if [[ -f "${dir}/Gemfile" ]]; then
    return 0
  fi

  parent="$(cd "${ROOT}/.." && pwd)"
  name="$(basename "${dir}")"
  ugm="${parent}/.gitmodules"

  if [[ -f "${ugm}" ]] && grep -q "path = ${name}" "${ugm}" 2>/dev/null; then
    log "initializing umbrella sample submodule ${name}"
    if git -C "${parent}" submodule update --init --recursive "${name}"; then
      if [[ -f "${dir}/Gemfile" ]]; then
        return 0
      fi
    fi
  fi

  log "warning: sample app missing at ${dir}"
  log "  expected sibling: ${parent}/${FLAVOR%-mise}-sample (umbrella submodule)"
  log "  or: SAMPLE_APP=/path/to/app"
  return 1
}

print_config() {
  cat <<EOF
FLAVOR=${FLAVOR}
IMAGE=${IMAGE}
CACHE_VOLUME=${CACHE_VOLUME}
USER=${USER}
IMAGE_USER=${IMAGE_USER}
DEV_UID=${DEV_UID}
DEV_GID=${DEV_GID}
SHELL=${SHELL}
PROJECT=${PROJECT}
POSTGRESQL_VERSION=${POSTGRESQL_VERSION:-}
TZ=${TZ:-$(host_timezone)}
HOST_KIND=$(host_kind)
ROOT=${ROOT}
SAMPLE_APP=${SAMPLE_APP}
EOF
}
