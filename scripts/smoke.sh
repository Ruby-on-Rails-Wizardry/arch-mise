#!/usr/bin/env bash
# Sample project smoke test — run *inside* the image after setup/warm.
#
#   task setup && task run -- ./scripts/smoke.sh
#   task compose:setup && task compose:run -- ./scripts/smoke.sh
#   ./bin/setup && ./bin/run ./scripts/smoke.sh
#
# Exit 0 only if mise tools, sample package managers, and cache env look healthy.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

echo "== sample smoke: pwd=$(pwd) =="

fail=0

ok() { printf 'OK  %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

run_check() {
  local name=$1
  shift
  if "$@" >/tmp/mise-sample-smoke.out 2>&1; then
    ok "${name}"
    # show first line of version-like output when present
    head -n 1 /tmp/mise-sample-smoke.out 2>/dev/null | sed 's/^/    /' || true
  else
    bad "${name}"
    sed 's/^/    /' /tmp/mise-sample-smoke.out 2>/dev/null || true
  fi
}

# Shell activation for mise shims (login shells already do this; one-shots may not).
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)" 2>/dev/null || true
  mise reshim 2>/dev/null || true
else
  bad "mise on PATH"
fi

run_check "ruby" ruby -v
run_check "node" node -v
run_check "yarn" yarn -v
run_check "python" python -v

if command -v bundle >/dev/null 2>&1; then
  run_check "bundle" bundle -v
  run_check "rails (bundle exec)" bundle exec rails -v
  run_check "rubocop (bundle exec)" bundle exec rubocop -V
  run_check "brakeman (bundle exec)" bundle exec brakeman --version
else
  bad "bundle on PATH"
fi

if [[ -d node_modules/ms ]] || [[ -f node_modules/ms/package.json ]]; then
  run_check "node require('ms')" node -e "require('ms'); console.log('ms', require('ms/package.json').version)"
else
  # yarn may hoist under /cache offline mirror but still link node_modules
  if command -v yarn >/dev/null 2>&1 && [[ -f yarn.lock ]]; then
    bad "node_modules/ms (run warm/yarn install)"
  else
    bad "yarn sample markers"
  fi
fi

if command -v python >/dev/null 2>&1; then
  run_check "python import requests" python -c "import requests; print('requests', requests.__version__)"
else
  bad "python for import check"
fi

# Cache contract (image ENV + volume)
if [[ -n "${CACHE_ROOT:-}" ]]; then
  ok "CACHE_ROOT=${CACHE_ROOT}"
  [[ -d "${CACHE_ROOT}" ]] && ok "CACHE_ROOT exists" || bad "CACHE_ROOT directory"
else
  bad "CACHE_ROOT unset"
fi

if [[ -n "${BUNDLE_PATH:-}" ]]; then
  ok "BUNDLE_PATH=${BUNDLE_PATH}"
  [[ -d "${BUNDLE_PATH}" ]] && ok "BUNDLE_PATH exists" || bad "BUNDLE_PATH directory"
else
  bad "BUNDLE_PATH unset"
fi

if [[ -n "${MISE_DATA_DIR:-}" ]]; then
  ok "MISE_DATA_DIR=${MISE_DATA_DIR}"
  [[ -d "${MISE_DATA_DIR}" ]] && ok "MISE_DATA_DIR exists" || bad "MISE_DATA_DIR directory"
else
  bad "MISE_DATA_DIR unset"
fi

if command -v cache-env >/dev/null 2>&1; then
  run_check "cache-env" cache-env
else
  bad "cache-env on PATH"
fi

echo
if [[ "${fail}" -eq 0 ]]; then
  echo "== sample smoke: all checks passed =="
  exit 0
fi
echo "== sample smoke: ${fail} check group(s) failed =="
exit 1
