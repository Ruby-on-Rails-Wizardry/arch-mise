# bash(1) login shells read this and skip ~/.profile — chain to profile.
if [ -f "${HOME}/.profile" ]; then
  # shellcheck disable=SC1090
  . "${HOME}/.profile"
fi
