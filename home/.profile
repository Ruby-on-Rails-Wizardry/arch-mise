# Login shells: bash / ksh / POSIX sh (dash, ash).
# PATH + mise shims; bash continues into ~/.bashrc for full activate.

# User scripts from the image home/ tree → ~/bin
if [ -d "${HOME}/bin" ]; then
  case ":${PATH}:" in
    *":${HOME}/bin:"*) ;;
    *) PATH="${HOME}/bin:${PATH}" ;;
  esac
fi

# mise installer binary
if [ -d "${HOME}/.local/bin" ]; then
  case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) PATH="${HOME}/.local/bin:${PATH}" ;;
  esac
fi

# Shared-volume shims (MISE_DATA_DIR=/cache/mise in these images)
if [ -n "${MISE_DATA_DIR:-}" ] && [ -d "${MISE_DATA_DIR}/shims" ]; then
  case ":${PATH}:" in
    *":${MISE_DATA_DIR}/shims:"*) ;;
    *) PATH="${MISE_DATA_DIR}/shims:${PATH}" ;;
  esac
fi

# Fallback shims location used by some mise layouts
if [ -d "${HOME}/.local/share/mise/shims" ]; then
  case ":${PATH}:" in
    *":${HOME}/.local/share/mise/shims:"*) ;;
    *) PATH="${HOME}/.local/share/mise/shims:${PATH}" ;;
  esac
fi
export PATH

# ksh reads $ENV for interactive sessions after login
if [ -z "${ENV:-}" ] && [ -f "${HOME}/.kshrc" ]; then
  export ENV="${HOME}/.kshrc"
fi

# bash login → interactive/non-interactive rc (mise activate lives there)
if [ -n "${BASH_VERSION:-}" ] && [ -f "${HOME}/.bashrc" ]; then
  # shellcheck disable=SC1090
  . "${HOME}/.bashrc"
fi
