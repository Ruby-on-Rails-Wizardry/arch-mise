#!/usr/bin/env bash
# Ensure /cache is present and writable for the image user, then exec CMD.
#
# Handles a common case: Docker named volumes mount as root:root and empty.
# Uses passwordless sudo when available; no-ops when already writable.

set -euo pipefail

CACHE_ROOT="${CACHE_ROOT:-/cache}"
USER_NAME="${USER:-$(id -un)}"
SUBDIRS=(mise mise-cache bundle rubygems yarn yarn-cache yarn-global npm pip uv poetry)

ensure_cache() {
  local d
  if [[ ! -d "${CACHE_ROOT}" ]] || [[ ! -w "${CACHE_ROOT}" ]]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo mkdir -p "${CACHE_ROOT}"
      for d in "${SUBDIRS[@]}"; do
        sudo mkdir -p "${CACHE_ROOT}/${d}"
      done
      sudo chown -R "${USER_NAME}:${USER_NAME}" "${CACHE_ROOT}"
      sudo chmod -R u+rwX,g+rwX,o+rX "${CACHE_ROOT}"
    else
      echo "docker-entrypoint: warning: ${CACHE_ROOT} not writable and sudo unavailable" >&2
      return 0
    fi
  fi

  for d in "${SUBDIRS[@]}"; do
    mkdir -p "${CACHE_ROOT}/${d}" 2>/dev/null || true
  done
}

ensure_cache

if [[ "$#" -eq 0 ]]; then
  set -- bash -l
fi

exec "$@"
