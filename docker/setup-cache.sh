#!/usr/bin/env bash
# Create /cache tree, install layout + helpers, wire login-shell env.
#
# Expected environment:
#   USER         image login name (default: dev)
#   CACHE_ROOT   root directory (default: /cache)
#   FLAVOR       install prefix name (ubuntu-mise | alpine-mise | arch-mise)
#
# Run as root after the image user exists.

set -euo pipefail

USER_NAME="${USER:-dev}"
CACHE_ROOT="${CACHE_ROOT:-/cache}"
FLAVOR="${FLAVOR:-ubuntu-mise}"
LIB_DIR="/usr/local/lib/${FLAVOR}"
SHARE_DIR="/usr/local/share/${FLAVOR}"

# Subdirs relative to CACHE_ROOT (must match cache-layout.env / Dockerfile ENV).
SUBDIRS=(
  mise
  mise-cache
  bundle
  rubygems
  yarn
  yarn-cache
  yarn-global
  npm
  pip
  uv
  poetry
)

log() {
  printf 'setup-cache: %s\n' "$*"
}

install_layout_files() {
  mkdir -p "${SHARE_DIR}" "${LIB_DIR}"

  if [[ -f /tmp/cache-layout.env ]]; then
    install -m 0644 /tmp/cache-layout.env "${SHARE_DIR}/cache-layout.env"
  fi
  if [[ -f /tmp/bundler-flags.yml ]]; then
    install -m 0644 /tmp/bundler-flags.yml "${SHARE_DIR}/bundler-flags.yml"
  fi
  if [[ -f /tmp/cache-env ]]; then
    install -m 0755 /tmp/cache-env "${LIB_DIR}/cache-env"
    ln -sfn "${LIB_DIR}/cache-env" /usr/local/bin/cache-env
  fi
  if [[ -f /tmp/verify-caches.sh ]]; then
    install -m 0755 /tmp/verify-caches.sh "${LIB_DIR}/verify-caches.sh"
  fi
  if [[ -f /tmp/docker-entrypoint.sh ]]; then
    install -m 0755 /tmp/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
  fi
}

create_cache_tree() {
  local d
  log "creating ${CACHE_ROOT}/{${SUBDIRS[*]}}"
  mkdir -p "${CACHE_ROOT}"
  for d in "${SUBDIRS[@]}"; do
    mkdir -p "${CACHE_ROOT}/${d}"
  done
  # Keep empty dirs visible in image layers / fresh volumes after ensure.
  for d in "${SUBDIRS[@]}"; do
    touch "${CACHE_ROOT}/${d}/.gitkeep"
  done
  chown -R "${USER_NAME}:${USER_NAME}" "${CACHE_ROOT}"
  chmod -R u+rwX,g+rwX,o+rX "${CACHE_ROOT}"
}

# POSIX-friendly env for bash/ksh/sh/zsh login (sourced from /etc/profile.d).
write_profile_d() {
  local dest="/etc/profile.d/zz-cache-env.sh"
  log "writing ${dest}"
  cat >"${dest}" <<'EOF'
# Shared package/tool caches for mise base images (ubuntu/alpine/arch-mise).
# Overridable via container ENV; defaults match Dockerfile.
#
# Yarn classic (1.x): YARN_CACHE_FOLDER + YARN_OFFLINE_MIRROR (+ classic .yarnrc)
# Yarn Berry (2+):    YARN_CACHE_FOLDER + YARN_GLOBAL_FOLDER + YARN_ENABLE_GLOBAL_CACHE
# Python:             PIP_CACHE_DIR + UV_CACHE_DIR + POETRY_CACHE_DIR

: "${CACHE_ROOT:=/cache}"

export CACHE_ROOT
export MISE_DATA_DIR="${MISE_DATA_DIR:-${CACHE_ROOT}/mise}"
export MISE_CACHE_DIR="${MISE_CACHE_DIR:-${CACHE_ROOT}/mise-cache}"
export BUNDLE_PATH="${BUNDLE_PATH:-${CACHE_ROOT}/bundle}"
export BUNDLE_CACHE_PATH="${BUNDLE_CACHE_PATH:-${CACHE_ROOT}/rubygems}"
# Shared name: classic cache-folder and Berry cacheFolder (different on-disk formats).
export YARN_CACHE_FOLDER="${YARN_CACHE_FOLDER:-${CACHE_ROOT}/yarn-cache}"
# Classic Yarn 1 offline mirror path (used by cache-env --write-yarnrc; not a Berry setting).
export YARN_OFFLINE_MIRROR="${YARN_OFFLINE_MIRROR:-${CACHE_ROOT}/yarn}"
# Berry: global store + enable shared global cache (YARN_* maps to .yarnrc.yml keys).
export YARN_GLOBAL_FOLDER="${YARN_GLOBAL_FOLDER:-${CACHE_ROOT}/yarn-global}"
export YARN_ENABLE_GLOBAL_CACHE="${YARN_ENABLE_GLOBAL_CACHE:-true}"
export NPM_CONFIG_CACHE="${NPM_CONFIG_CACHE:-${CACHE_ROOT}/npm}"
export npm_config_cache="${npm_config_cache:-${NPM_CONFIG_CACHE}}"
# Python package caches (pip / uv / poetry — not interchangeable on disk).
export PIP_CACHE_DIR="${PIP_CACHE_DIR:-${CACHE_ROOT}/pip}"
export UV_CACHE_DIR="${UV_CACHE_DIR:-${CACHE_ROOT}/uv}"
export POETRY_CACHE_DIR="${POETRY_CACHE_DIR:-${CACHE_ROOT}/poetry}"
# Prefer project-local .venv; only package cache is shared under /cache.
export POETRY_VIRTUALENVS_IN_PROJECT="${POETRY_VIRTUALENVS_IN_PROJECT:-true}"

# Prefer mise shims from shared data dir when present.
case ":${PATH}:" in
  *":${MISE_DATA_DIR}/shims:"*) ;;
  *) PATH="${MISE_DATA_DIR}/shims:${PATH}" ;;
esac
export PATH

# Best-effort create dirs on a fresh volume (must be writable by this user).
if [ -d "${CACHE_ROOT}" ] && [ -w "${CACHE_ROOT}" ]; then
  for _d in mise mise-cache bundle rubygems yarn yarn-cache yarn-global npm pip uv poetry; do
    mkdir -p "${CACHE_ROOT}/${_d}" 2>/dev/null || true
  done
  unset _d
fi
EOF
  chmod 0644 "${dest}"
}

write_fish_conf() {
  local dest="/etc/fish/conf.d/zz-cache-env.fish"
  mkdir -p "$(dirname "${dest}")"
  log "writing ${dest}"
  cat >"${dest}" <<'EOF'
# Shared package/tool caches for mise base images (Ruby/JS/Python).
if not set -q CACHE_ROOT
  set -gx CACHE_ROOT /cache
end
if not set -q MISE_DATA_DIR
  set -gx MISE_DATA_DIR "$CACHE_ROOT/mise"
end
if not set -q MISE_CACHE_DIR
  set -gx MISE_CACHE_DIR "$CACHE_ROOT/mise-cache"
end
if not set -q BUNDLE_PATH
  set -gx BUNDLE_PATH "$CACHE_ROOT/bundle"
end
if not set -q BUNDLE_CACHE_PATH
  set -gx BUNDLE_CACHE_PATH "$CACHE_ROOT/rubygems"
end
if not set -q YARN_CACHE_FOLDER
  set -gx YARN_CACHE_FOLDER "$CACHE_ROOT/yarn-cache"
end
if not set -q YARN_OFFLINE_MIRROR
  set -gx YARN_OFFLINE_MIRROR "$CACHE_ROOT/yarn"
end
if not set -q YARN_GLOBAL_FOLDER
  set -gx YARN_GLOBAL_FOLDER "$CACHE_ROOT/yarn-global"
end
if not set -q YARN_ENABLE_GLOBAL_CACHE
  set -gx YARN_ENABLE_GLOBAL_CACHE true
end
if not set -q NPM_CONFIG_CACHE
  set -gx NPM_CONFIG_CACHE "$CACHE_ROOT/npm"
end
set -gx npm_config_cache $NPM_CONFIG_CACHE
if not set -q PIP_CACHE_DIR
  set -gx PIP_CACHE_DIR "$CACHE_ROOT/pip"
end
if not set -q UV_CACHE_DIR
  set -gx UV_CACHE_DIR "$CACHE_ROOT/uv"
end
if not set -q POETRY_CACHE_DIR
  set -gx POETRY_CACHE_DIR "$CACHE_ROOT/poetry"
end
if not set -q POETRY_VIRTUALENVS_IN_PROJECT
  set -gx POETRY_VIRTUALENVS_IN_PROJECT true
end

if test -d "$MISE_DATA_DIR/shims"
  if not contains -- "$MISE_DATA_DIR/shims" $PATH
    set -gx PATH "$MISE_DATA_DIR/shims" $PATH
  end
end

if test -d "$CACHE_ROOT"; and test -w "$CACHE_ROOT"
  for _d in mise mise-cache bundle rubygems yarn yarn-cache yarn-global npm pip uv poetry
    mkdir -p "$CACHE_ROOT/$_d" 2>/dev/null
  end
end
EOF
  chmod 0644 "${dest}"
}

main() {
  log "USER=${USER_NAME} CACHE_ROOT=${CACHE_ROOT} FLAVOR=${FLAVOR}"
  install_layout_files
  create_cache_tree
  write_profile_d
  write_fish_conf
  log "done"
}

main "$@"
