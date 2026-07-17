#!/usr/bin/env bash
# Create or rename the non-root image user for bind-mount-friendly UID/GID.
#
# Expected environment (Docker build ARGs):
#   USER      login name (default: dev)
#   DEV_UID   numeric uid (default: 1000)
#   DEV_GID   numeric gid (default: 1000)
#
# Ubuntu base images often already ship ubuntu:1000:1000 — we rename that
# account when it collides rather than failing groupadd/useradd.

set -euo pipefail

USER_NAME="${USER:-dev}"
DEV_UID="${DEV_UID:-1000}"
DEV_GID="${DEV_GID:-1000}"
HOME_DIR="/home/${USER_NAME}"

log() {
  printf 'setup-user: %s\n' "$*"
}

ensure_group() {
  local gid="$1"
  local name="$2"
  local existing

  if ! getent group "${gid}" >/dev/null; then
    log "creating group ${name} (gid ${gid})"
    groupadd --gid "${gid}" "${name}"
    return
  fi

  existing="$(getent group "${gid}" | cut -d: -f1)"
  if [[ "${existing}" != "${name}" ]]; then
    log "renaming group ${existing} → ${name} (gid ${gid})"
    groupmod -n "${name}" "${existing}"
  else
    log "group ${name} already exists (gid ${gid})"
  fi
}

ensure_user() {
  local uid="$1"
  local gid="$2"
  local name="$3"
  local existing

  if getent passwd "${uid}" >/dev/null; then
    existing="$(getent passwd "${uid}" | cut -d: -f1)"
    if [[ "${existing}" != "${name}" ]]; then
      log "renaming user ${existing} → ${name} (uid ${uid}), home ${HOME_DIR}"
      usermod -l "${name}" -d "${HOME_DIR}" -m "${existing}"
    else
      log "user ${name} already exists (uid ${uid})"
    fi
  else
    ensure_group "${gid}" "${name}"
    log "creating user ${name} (uid ${uid}, gid ${gid})"
    useradd --uid "${uid}" --gid "${gid}" --create-home --shell /bin/bash "${name}"
  fi

  # Primary group for this uid may still carry the old name (e.g. ubuntu).
  ensure_group "${gid}" "${name}"
}

grant_passwordless_sudo() {
  local name="$1"
  local sudoers="/etc/sudoers.d/${name}"

  usermod -aG sudo "${name}" 2>/dev/null || true
  log "passwordless sudo → ${sudoers}"
  echo "${name} ALL=(ALL) NOPASSWD:ALL" >"${sudoers}"
  chmod 0440 "${sudoers}"
}

prepare_home() {
  local name="$1"

  log "ensuring ${HOME_DIR}"
  mkdir -p "${HOME_DIR}"
  # Silence Ubuntu /etc/bash.bashrc "run a command as administrator" banner.
  touch "${HOME_DIR}/.sudo_as_admin_successful"
  chown -R "${name}:${name}" "${HOME_DIR}"
}

main() {
  log "USER=${USER_NAME} DEV_UID=${DEV_UID} DEV_GID=${DEV_GID}"

  ensure_user "${DEV_UID}" "${DEV_GID}" "${USER_NAME}"
  grant_passwordless_sudo "${USER_NAME}"
  prepare_home "${USER_NAME}"

  log "done"
}

main "$@"
