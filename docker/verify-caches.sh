#!/usr/bin/env bash
# Verify shared /cache layout and environment for mise base images.

set -euo pipefail

CACHE_ROOT="${CACHE_ROOT:-/cache}"
pass=0
fail=0

check() {
  local name="$1"
  shift
  echo "=== ${name} ==="
  if "$@"; then
    printf 'OK  %s\n' "${name}"
    pass=$((pass + 1))
  else
    printf 'FAIL %s\n' "${name}"
    fail=$((fail + 1))
  fi
  echo
}

dir_writable() {
  local d="$1"
  [[ -d "${d}" ]] && [[ -w "${d}" ]]
}

env_points_under_cache() {
  local var="$1"
  local val="${!var:-}"
  [[ -n "${val}" ]] && [[ "${val}" == "${CACHE_ROOT}"/* || "${val}" == "${CACHE_ROOT}" ]]
}

env_equals() {
  local var="$1"
  local want="$2"
  local val="${!var:-}"
  [[ "${val}" == "${want}" ]]
}

cache_env_on_path() {
  command -v cache-env >/dev/null 2>&1
}

cache_env_prints_paths() {
  local out
  out="$(cache-env)"
  printf '%s\n' "${out}" | grep -q "^BUNDLE_PATH=${CACHE_ROOT}/bundle" \
    && printf '%s\n' "${out}" | grep -q "^YARN_GLOBAL_FOLDER=${CACHE_ROOT}/yarn-global" \
    && printf '%s\n' "${out}" | grep -q "^YARN_ENABLE_GLOBAL_CACHE=" \
    && printf '%s\n' "${out}" | grep -q "^PIP_CACHE_DIR=${CACHE_ROOT}/pip" \
    && printf '%s\n' "${out}" | grep -q "^UV_CACHE_DIR=${CACHE_ROOT}/uv" \
    && printf '%s\n' "${out}" | grep -q "^POETRY_CACHE_DIR=${CACHE_ROOT}/poetry"
}

cache_env_writes_classic_yarnrc() {
  local tmp
  tmp="$(mktemp -d)"
  (
    cd "${tmp}"
    cache-env --write-yarnrc >/dev/null
    grep -q 'yarn-offline-mirror' .yarnrc
    grep -q "${CACHE_ROOT}/yarn" .yarnrc
  )
  local rc=$?
  rm -rf "${tmp}"
  return "${rc}"
}

cache_env_writes_berry_yarnrc() {
  local tmp
  tmp="$(mktemp -d)"
  (
    cd "${tmp}"
    cache-env --write-yarnrc-yml >/dev/null
    grep -q 'enableGlobalCache: true' .yarnrc.yml
    grep -q "globalFolder: \"${CACHE_ROOT}/yarn-global\"" .yarnrc.yml
    grep -q "cacheFolder: \"${CACHE_ROOT}/yarn-cache\"" .yarnrc.yml
  )
  local rc=$?
  rm -rf "${tmp}"
  return "${rc}"
}

cache_env_writes_pip_conf() {
  local tmp
  tmp="$(mktemp -d)"
  (
    cd "${tmp}"
    cache-env --write-pip-conf >/dev/null
    grep -q "cache-dir = ${CACHE_ROOT}/pip" pip.conf
  )
  local rc=$?
  rm -rf "${tmp}"
  return "${rc}"
}

echo "CACHE_ROOT=${CACHE_ROOT}"
echo "USER=$(id -un) uid=$(id -u)"

check "CACHE_ROOT exists" dir_writable "${CACHE_ROOT}"

for d in mise mise-cache bundle rubygems yarn yarn-cache yarn-global npm pip uv poetry; do
  check "dir ${CACHE_ROOT}/${d}" dir_writable "${CACHE_ROOT}/${d}"
done

# shellcheck disable=SC1091
if [[ -f /etc/profile.d/zz-cache-env.sh ]]; then
  # shellcheck source=/dev/null
  source /etc/profile.d/zz-cache-env.sh
fi

for var in MISE_DATA_DIR MISE_CACHE_DIR BUNDLE_PATH BUNDLE_CACHE_PATH \
  YARN_CACHE_FOLDER YARN_OFFLINE_MIRROR YARN_GLOBAL_FOLDER NPM_CONFIG_CACHE \
  PIP_CACHE_DIR UV_CACHE_DIR POETRY_CACHE_DIR; do
  check "env ${var} under CACHE_ROOT" env_points_under_cache "${var}"
done

check "env YARN_ENABLE_GLOBAL_CACHE true" env_equals YARN_ENABLE_GLOBAL_CACHE true
check "env POETRY_VIRTUALENVS_IN_PROJECT true" env_equals POETRY_VIRTUALENVS_IN_PROJECT true

check "cache-env on PATH" cache_env_on_path
check "cache-env prints paths" cache_env_prints_paths
check "cache-env --write-yarnrc (classic)" cache_env_writes_classic_yarnrc
check "cache-env --write-yarnrc-yml (Berry)" cache_env_writes_berry_yarnrc
check "cache-env --write-pip-conf" cache_env_writes_pip_conf

echo "passed=${pass} failed=${fail}"
[[ "${fail}" -eq 0 ]]
