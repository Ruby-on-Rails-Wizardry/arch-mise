# fish: /docker/bin + mise on PATH; full activate when mise is installed.

if test -d /docker/bin
  fish_add_path -p /docker/bin
end
if test -d "$HOME/bin"
  fish_add_path -p "$HOME/bin"
end
if test -d "$HOME/.local/bin"
  fish_add_path -p "$HOME/.local/bin"
end
if test -n "$MISE_DATA_DIR"; and test -d "$MISE_DATA_DIR/shims"
  fish_add_path -p "$MISE_DATA_DIR/shims"
end

if test -x "$HOME/.local/bin/mise"
  "$HOME/.local/bin/mise" activate fish | source
end
