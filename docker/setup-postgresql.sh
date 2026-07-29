#!/usr/bin/env bash
# Install PostgreSQL client tools and libpq development headers (for the pg gem).
#
# Arch ships a rolling PostgreSQL (postgresql-libs = client + libpq). There is no
# multi-version client stack; POSTGRESQL_VERSION records the intended major and
# is checked against the installed package when possible.
#
# Expected environment (Docker build ARG / ENV):
#   POSTGRESQL_VERSION  major version (e.g. 17, 18).
#                       Empty / unset → no install (exit 0).
#
# Installs when version is set:
#   postgresql-libs  — psql/client binaries + libpq headers/libs

set -euo pipefail

POSTGRESQL_VERSION="${POSTGRESQL_VERSION:-}"

log() {
  printf 'setup-postgresql: %s\n' "$*"
}

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "setup-postgresql: must run as root" >&2
    exit 1
  fi
}

install_client_and_dev() {
  log "installing postgresql-libs (client + libpq; Arch rolling)"
  pacman -Sy --noconfirm
  pacman -S --noconfirm --needed postgresql-libs
  pacman -Scc --noconfirm 2>/dev/null || true

  log "psql: $(psql --version 2>/dev/null || echo 'not on PATH')"
  if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists libpq 2>/dev/null; then
    log "libpq: $(pkg-config --modversion libpq)"
  fi

  # Best-effort major check (e.g. "psql (PostgreSQL) 18.4").
  local ver_line major
  ver_line="$(psql --version 2>/dev/null || true)"
  if [[ "${ver_line}" =~ ([0-9]+)\.[0-9]+ ]]; then
    major="${BASH_REMATCH[1]}"
    if [[ "${major}" != "${POSTGRESQL_VERSION}" ]]; then
      echo "setup-postgresql: warning: requested major ${POSTGRESQL_VERSION} but installed psql reports ${major} (Arch rolling)" >&2
    fi
  fi
}

main() {
  require_root

  if [[ -z "${POSTGRESQL_VERSION}" ]]; then
    log "POSTGRESQL_VERSION unset — skipping PostgreSQL client install"
    exit 0
  fi

  if ! [[ "${POSTGRESQL_VERSION}" =~ ^[0-9]+$ ]]; then
    echo "setup-postgresql: POSTGRESQL_VERSION must be a major number (got: ${POSTGRESQL_VERSION})" >&2
    exit 1
  fi

  log "POSTGRESQL_VERSION=${POSTGRESQL_VERSION}"
  install_client_and_dev
  log "done"
}

main "$@"
