# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

# User configuration
# export MANPATH="/usr/local/man:$MANPATH"
# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi
export EDITOR=vim
export VISUAL=vim
# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"
alias claude-e2e="CLAUDE_CONFIG_DIR=~/.claude-e2e claude"

# Keep BSD ls colorized on macOS terminals (Ghostty/Starship only render these colors).
export CLICOLOR=1
alias ls='ls -G'

export PATH=$PATH:~/.local/bin
export MYSQLCLIENT_CFLAGS=$(mysql_config --cflags)
export MYSQLCLIENT_LDFLAGS=$(mysql_config --libs)
export GOPATH="${HOME}/code/go"

export GPG_KEY_ID=72980C0F4BF701C8

E2E_AGENT_PROFILES_DIR="${HOME}/.config/clawable"
E2E_AGENT_ENV_FILE="${E2E_AGENT_PROFILES_DIR}/.env_mac"

if [[ -f "${E2E_AGENT_ENV_FILE}" ]]; then
  set -a
  source "${E2E_AGENT_ENV_FILE}"
  set +a
  echo "\033[32m✔\033[0m Found ${E2E_AGENT_ENV_FILE}"
elif command -v pass-cli >/dev/null 2>&1; then
  _pass_key() {
    pass-cli item view --vault-name AGENTS_BUFFET --item-title "$1" --field password 2>/dev/null
  }

  _pass_field() {
    pass-cli item view --vault-name AGENTS_BUFFET --item-title "$1" --field "$2" 2>/dev/null
  }

  mkdir -p "${E2E_AGENT_PROFILES_DIR}"
  : > "${E2E_AGENT_ENV_FILE}"
  chmod 600 "${E2E_AGENT_ENV_FILE}"

  _agent_keys=(
    OLLAMA_CLOUD_API_KEY
    GITHUB_PERSONAL_ACCESS_TOKEN
    GITLAB_PERSONAL_ACCESS_TOKEN
    MODAL_API_KEY
    MOONSHOT_API_KEY
    OPENAI_API_KEY
    ZAI_API_KEY
    MINIMAX_API_KEY
    OPENROUTER_API_KEY
    NPM_TOKEN
  )

  for _k in "${_agent_keys[@]}"; do
    _v="$(_pass_key "$_k")"
    if [[ -n "$_v" ]]; then
      echo "export ${_k}=\"${_v}\"" >> "${E2E_AGENT_ENV_FILE}"
      export "${_k}=${_v}"
      echo "\033[32m✔\033[0m Pulled ${_k} → ${E2E_AGENT_ENV_FILE}"
    else
      echo "\033[33m⚠\033[0m Skipped ${_k} (not found in vault)"
    fi
  done

  unset _k _v _agent_keys
  unset -f _pass_key

  # Docker registry credentials (username + password fields)
  _docker_creds() {
    local vault_item="$1" user_var="$2" pass_var="$3" user pass
    user=$(_pass_field "$vault_item" username)
    pass=$(_pass_field "$vault_item" password)
    [[ -n "$user" && -n "$pass" ]] || return
    echo "export $user_var=\"$user\"" >> "$E2E_AGENT_ENV_FILE"
    echo "export $pass_var=\"$pass\"" >> "$E2E_AGENT_ENV_FILE"
    export "$user_var=$user" "$pass_var=$pass"
    echo "\033[32m✔\033[0m Pulled $vault_item"
  }

  _docker_creds DOCKER_REGISTRY_INFRA DOCKER_USER_INFRA DOCKER_PASS_INFRA
  _docker_creds DOCKER_REGISTRY_MARKETPLACE DOCKER_USER_MARKETPLACE DOCKER_PASS_MARKETPLACE
  _docker_creds DOCKER_REGISTRY_MYACCOUNT DOCKER_USER_MYACCOUNT DOCKER_PASS_MYACCOUNT

  # Set default DOCKER_USER/DOCKER_PASS from INFRA for backward compatibility
  if [[ -n "${DOCKER_USER_INFRA:-}" ]]; then
    echo "export DOCKER_USER=\"$DOCKER_USER_INFRA\"" >> "$E2E_AGENT_ENV_FILE"
    echo "export DOCKER_PASS=\"$DOCKER_PASS_INFRA\"" >> "$E2E_AGENT_ENV_FILE"
    export DOCKER_USER="$DOCKER_USER_INFRA" DOCKER_PASS="$DOCKER_PASS_INFRA"
  fi

  unset -f _pass_field _docker_creds
fi
eval "$("${HOME}/.local/bin/mise" activate zsh)"

export PATH="/opt/homebrew/opt/libxml2/bin:${HOME}/.local/share/mise/shims:${HOME}/.bun/bin:$PATH"

eval "$(starship init zsh)"

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# opencode
export PATH="${HOME}/.opencode/bin:/usr/local/bin:${HOME}/bin:$PATH"

# bun completions
[ -s "${HOME}/.bun/_bun" ] && source "${HOME}/.bun/_bun"

export PATH="/opt/homebrew/opt/trash/bin:$PATH"

# Upgrade all AI coding tools in one shot
upgrade-ai() {
  claude upgrade
  opencode upgrade
  kilo upgrade
  npm install -g @openai/codex @mariozechner/pi-coding-agent @steipete/oracle
}
