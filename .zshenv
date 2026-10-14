# LSCOLORS for BSD ls (macOS) - neon color scheme
# Directories=neon yellow, Symlinks=neon magenta, Executables=neon green
# Sockets/Pipes=neon orange, Special=neon cyan, Setuid/gid=neon red
export LSCOLORS="DxFxdxdxCxGxGxBxBxDcDd"
export CLICOLOR=1

# Generated exports also belong to non-interactive Cargo, Make and orly commands.
if [[ -f "${HOME}/.config/agentsfleet/.env" ]]; then
  source "${HOME}/.config/agentsfleet/.env"
fi
