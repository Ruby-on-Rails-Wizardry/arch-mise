# Interactive zsh: PATH + full mise activate.

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
export PATH

if [ -x "${HOME}/.local/bin/mise" ]; then
  eval "$("${HOME}/.local/bin/mise" activate zsh)"
fi
