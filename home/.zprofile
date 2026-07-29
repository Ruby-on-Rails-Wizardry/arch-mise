# zsh login (zsh -lc reads this, not always .zshrc). Shims + ~/bin on PATH.

if [ -d "${HOME}/bin" ]; then
  case ":${PATH}:" in
    *":${HOME}/bin:"*) ;;
    *) PATH="${HOME}/bin:${PATH}" ;;
  esac
fi
if [ -d "${HOME}/.local/bin" ]; then
  case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) PATH="${HOME}/.local/bin:${PATH}" ;;
  esac
fi
if [ -n "${MISE_DATA_DIR:-}" ] && [ -d "${MISE_DATA_DIR}/shims" ]; then
  case ":${PATH}:" in
    *":${MISE_DATA_DIR}/shims:"*) ;;
    *) PATH="${MISE_DATA_DIR}/shims:${PATH}" ;;
  esac
fi
if [ -d "${HOME}/.local/share/mise/shims" ]; then
  case ":${PATH}:" in
    *":${HOME}/.local/share/mise/shims:"*) ;;
    *) PATH="${HOME}/.local/share/mise/shims:${PATH}" ;;
  esac
fi
export PATH
