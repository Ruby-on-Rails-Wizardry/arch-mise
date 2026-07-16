#!/usr/bin/env bash
# Wire mise into login and interactive shells for the image user.
#
# Supported shells: bash, ksh, sh (bash-as-sh on Arch), zsh, fish.
#
# Strategy:
#   - ~/.profile              — portable shims PATH + ksh ENV (+ source bashrc for bash)
#   - ~/.bash_profile         — Arch skel has this, so bash login skips ~/.profile;
#                               we point it at ~/.profile instead
#   - ~/.bashrc               — full `mise activate bash` (interactive bash)
#   - ~/.kshrc                — shims PATH (interactive ksh; ENV set from .profile)
#   - ~/.zprofile             — shims PATH (zsh login; zsh -lc does not read .zshrc)
#   - ~/.zshrc                — full `mise activate zsh` (interactive zsh)
#   - ~/.config/fish/config.fish — `mise activate fish | source`
#                               (fish loads this for login, including fish -lc)
#
# mise activate exists for bash/zsh/fish/…, not ksh. ksh uses shims on PATH.

set -euo pipefail

HOME_DIR="${HOME:?HOME must be set}"
MISE_BIN="${HOME_DIR}/.local/bin/mise"
PROFILE="${HOME_DIR}/.profile"
BASH_PROFILE="${HOME_DIR}/.bash_profile"
BASHRC="${HOME_DIR}/.bashrc"
KSHRC="${HOME_DIR}/.kshrc"
ZPROFILE="${HOME_DIR}/.zprofile"
ZSHRC="${HOME_DIR}/.zshrc"
FISH_CONFIG="${HOME_DIR}/.config/fish/config.fish"

MARKER_BEGIN="# >>> mise (arch-mise) >>>"
MARKER_END="# <<< mise (arch-mise) <<<"

log() {
  printf 'setup-mise-shell: %s\n' "$*"
}

append_block() {
  local file="$1"
  local body="$2"

  mkdir -p "$(dirname "${file}")"
  touch "${file}"

  if grep -Fq "${MARKER_BEGIN}" "${file}" 2>/dev/null; then
    log "block already present in ${file}"
    return
  fi

  log "appending mise block → ${file}"
  {
    printf '\n%s\n' "${MARKER_BEGIN}"
    printf '%s\n' "${body}"
    printf '%s\n' "${MARKER_END}"
  } >>"${file}"
}

# Portable PATH snippet for POSIX-ish shells (profile, kshrc, zprofile).
# Bodies are written with heredocs so ${HOME}/${PATH} expand when *sourced*.
read -r -d '' SHIMS_PATH_BODY <<'EOF' || true
# mise binary + shims on PATH (portable; no shell-specific activate).
if [ -d "${HOME}/.local/bin" ]; then
  case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) PATH="${HOME}/.local/bin:${PATH}" ;;
  esac
fi
if [ -d "${HOME}/.local/share/mise/shims" ]; then
  case ":${PATH}:" in
    *":${HOME}/.local/share/mise/shims:"*) ;;
    *) PATH="${HOME}/.local/share/mise/shims:${PATH}" ;;
  esac
fi
export PATH
EOF

read -r -d '' PROFILE_BODY <<'EOF' || true
# mise binary + shims on PATH (portable for bash, ksh, and sh login shells).
if [ -d "${HOME}/.local/bin" ]; then
  case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) PATH="${HOME}/.local/bin:${PATH}" ;;
  esac
fi
if [ -d "${HOME}/.local/share/mise/shims" ]; then
  case ":${PATH}:" in
    *":${HOME}/.local/share/mise/shims:"*) ;;
    *) PATH="${HOME}/.local/share/mise/shims:${PATH}" ;;
  esac
fi
export PATH

# ksh reads $ENV for interactive shells after login.
if [ -z "${ENV:-}" ] && [ -f "${HOME}/.kshrc" ]; then
  export ENV="${HOME}/.kshrc"
fi

# Arch has no skel .profile that sources bashrc; mirror Ubuntu so bash login
# gets full interactive mise activate from ~/.bashrc.
if [ -n "${BASH_VERSION:-}" ] && [ -f "${HOME}/.bashrc" ]; then
  # shellcheck disable=SC1091
  . "${HOME}/.bashrc"
fi
EOF

read -r -d '' BASHRC_BODY <<'EOF' || true
# Full mise activation for interactive bash (hook-env, PATH, etc.).
if [ -x "${HOME}/.local/bin/mise" ]; then
  eval "$("${HOME}/.local/bin/mise" activate bash)"
fi
EOF

read -r -d '' ZSHRC_BODY <<'EOF' || true
# Full mise activation for interactive zsh (hook-env, PATH, etc.).
if [ -x "${HOME}/.local/bin/mise" ]; then
  eval "$("${HOME}/.local/bin/mise" activate zsh)"
fi
EOF

read -r -d '' FISH_BODY <<'EOF' || true
# Full mise activation for fish (login + interactive load config.fish).
if test -x "$HOME/.local/bin/mise"
  "$HOME/.local/bin/mise" activate fish | source
end
EOF

if [[ ! -x "${MISE_BIN}" ]]; then
  log "error: mise not found at ${MISE_BIN}"
  exit 1
fi

append_block "${PROFILE}" "${PROFILE_BODY}"
append_block "${BASHRC}" "${BASHRC_BODY}"
append_block "${KSHRC}" "${SHIMS_PATH_BODY}"
append_block "${ZPROFILE}" "${SHIMS_PATH_BODY}"
append_block "${ZSHRC}" "${ZSHRC_BODY}"
append_block "${FISH_CONFIG}" "${FISH_BODY}"

# Arch /etc/skel ships ~/.bash_profile that only sources ~/.bashrc. Bash login
# never reads ~/.profile when .bash_profile exists, so non-interactive bash -l
# would miss mise shims (bashrc returns early for non-interactive). Rewrite to
# a single chain: .bash_profile → .profile → (.bashrc when bash).
if grep -Fq "${MARKER_BEGIN}" "${BASH_PROFILE}" 2>/dev/null; then
  log "block already present in ${BASH_PROFILE}"
else
  log "writing login chain → ${BASH_PROFILE}"
  cat >"${BASH_PROFILE}" <<'EOF'
#
# ~/.bash_profile
#

# bash(1): login shells read this file and skip ~/.profile. Source profile so
# mise PATH (and interactive bashrc) apply on bash -l as well as ksh/sh login.
# >>> mise (arch-mise) >>>
if [ -f "${HOME}/.profile" ]; then
  # shellcheck disable=SC1091
  . "${HOME}/.profile"
fi
# <<< mise (arch-mise) <<<
EOF
fi

log "done"
