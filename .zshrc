# --- PATH (consolidated, deduped) ---
typeset -U path PATH
path=(
  "$HOME/.opencode/bin"
  "/opt/homebrew/opt/trash/bin"
  "/opt/homebrew/opt/libxml2/bin"
  "$HOME/.bun/bin"
  "$HOME/.local/bin"
  "/usr/local/bin"
  "$HOME/bin"
  $path
)
export PATH

# --- Exports ---
export EDITOR=vim
export VISUAL=vim
export CLICOLOR=1
export GOPATH="${HOME}/code/go"
export GPG_KEY_ID=72980C0F4BF701C8

# --- agentsfleet dev defaults ---
export AGENTSFLEET_STATE_DIR=/tmp/agentsfleet-local-test
export AGENTSFLEET_API_URL=http://localhost:3000
export AGENTSFLEET_TELEMETRY_DISABLED=1

# --- Aliases ---
alias ls='ls -G'
alias claude='CLAUDE_CONFIG_DIR=$HOME/.claude $HOME/.local/bin/claude'
alias claude2='CLAUDE_CONFIG_DIR=$HOME/.claude2 $HOME/.local/bin/claude'
alias codex='codex --no-alt-screen'
# Fix TERM for SSH connections to servers without ghostty terminfo
alias ssh='TERM=xterm-256color ssh'

# --- Build flags (loaded on startup) ---
use-mysqlclient-build-flags() {
  if command -v mysql_config >/dev/null 2>&1; then
    export MYSQLCLIENT_CFLAGS="$(mysql_config --cflags)"
    export MYSQLCLIENT_LDFLAGS="$(mysql_config --libs)"
  fi
}

use-freetype-build-flags() {
  export CFLAGS="-I/opt/homebrew/include/freetype2"
  export CPPFLAGS="-I/opt/homebrew/include/freetype2"
  export LDFLAGS="-L/opt/homebrew/lib"
  export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig"
}

use-mysqlclient-build-flags
use-freetype-build-flags

# --- Env files (flat, provisioned via ~/bin/provision-env-1password) ---
[[ -f "${HOME}/.config/agentsfleet/.env" ]] && { set -a; source "${HOME}/.config/agentsfleet/.env"; set +a; }
[[ -f "${HOME}/.config/e2e/.env" ]]       && { set -a; source "${HOME}/.config/e2e/.env"; set +a; }

# --- Tool activation ---
if [[ -x "${HOME}/.local/bin/mise" ]]; then
  eval "$("${HOME}/.local/bin/mise" activate zsh)"
fi

# --- Completions ---
[[ -s "${HOME}/.bun/_bun" ]] && source "${HOME}/.bun/_bun"

# --- Prompt (last) ---
eval "$(starship init zsh)"

# --- iTerm2 (gated) ---
if [[ "${TERM_PROGRAM:-}" == "iTerm.app" && -r "${HOME}/.iterm2_shell_integration.zsh" ]]; then
  source "${HOME}/.iterm2_shell_integration.zsh"
fi

# Added by flyctl installer
export FLYCTL_INSTALL="/Users/kishore/.fly"
export PATH="$FLYCTL_INSTALL/bin:$PATH"

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<

# >>> railway initialize >>>
[[ -s "$HOME/.railway/env" ]] && source "$HOME/.railway/env"
# <<< railway initialize <<<
