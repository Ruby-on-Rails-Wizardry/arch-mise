#!/usr/bin/env bash
# Sanity-check shell defaults after mise install.
#
# PATH, mise activate, ~/bin tools, and language globals live in the repo home/
# tree (copied into /home/$USER at build). This step only verifies the image is
# usable — it does not rewrite shell rc files.

set -euo pipefail

HOME_DIR="${HOME:?HOME must be set}"
MISE_BIN="${HOME_DIR}/.local/bin/mise"
BIN_DIR="${HOME_DIR}/bin"

log() {
  printf 'setup-mise-shell: %s\n' "$*"
}

if [[ ! -x "${MISE_BIN}" ]]; then
  log "error: mise not found at ${MISE_BIN}"
  exit 1
fi

missing=0
for f in .profile .bashrc .bash_profile .kshrc .zprofile .zshrc .config/fish/config.fish; do
  if [[ ! -e "${HOME_DIR}/${f}" ]]; then
    log "error: missing home seed file: ${f}"
    missing=1
  fi
done

for f in cache-env docker-entrypoint verify-caches verify-login-shells; do
  if [[ ! -x "${BIN_DIR}/${f}" ]]; then
    log "error: missing runtime tool: bin/${f} (seed from home/bin/)"
    missing=1
  fi
done

if [[ "${missing}" -ne 0 ]]; then
  exit 1
fi

log "ok: home shell defaults + ~/bin tools present; mise at ${MISE_BIN}"
log "done"
