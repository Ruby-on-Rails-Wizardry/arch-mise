#!/usr/bin/env bash
# Verify that login shells resolve and run mise after rc/profile setup.
# Intended to run *inside* the image.
#
# Usage:
#   docker run --rm --entrypoint /usr/local/lib/arch-mise/verify-login-shells.sh IMAGE
#
# We strip any pre-seeded mise PATH so success means shell startup files work.

set -euo pipefail

# Minimal PATH without mise — shell profiles must re-add it.
export PATH=/usr/bin:/bin

pass=0
fail=0

check() {
  local name="$1"
  shift
  local out
  echo "=== ${name} ==="
  if out="$("$@" 2>&1)"; then
    if printf '%s\n' "${out}" | grep -qE '^[0-9]+\.[0-9]+'; then
      printf 'OK  %s\n%s\n' "${name}" "${out}"
      pass=$((pass + 1))
    else
      printf 'FAIL %s (no mise version in output)\n%s\n' "${name}" "${out}"
      fail=$((fail + 1))
    fi
  else
    printf 'FAIL %s (command failed)\n%s\n' "${name}" "${out}"
    fail=$((fail + 1))
  fi
  echo
}

# Each invocation: login shell, print where mise is + its version.
# zsh -lc: only .zprofile (shims). fish -lc: loads config.fish (full activate).
# On Arch, /bin/sh is bash; ksh is the official AT&T package.
check "bash -l" bash -lc 'command -v mise; mise --version'
check "ksh -l"  ksh  -lc 'command -v mise; mise --version'
check "sh -l"   sh   -lc 'command -v mise; mise --version'
check "zsh -l"  zsh  -lc 'command -v mise; mise --version'
check "fish -l" fish -lc 'command -v mise; mise --version'

echo "passed=${pass} failed=${fail}"
[[ "${fail}" -eq 0 ]]
