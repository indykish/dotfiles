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
  _pass_field() {
    pass-cli item view --vault-name AGENTS_BUFFET --item-title "$1" --field "$2" 2>/dev/null
  }
  _emit() { echo "export $1=\"$2\"" >> "${E2E_AGENT_ENV_FILE}"; export "$1=$2"; }

  mkdir -p "${E2E_AGENT_PROFILES_DIR}"
  : > "${E2E_AGENT_ENV_FILE}"
  chmod 600 "${E2E_AGENT_ENV_FILE}"

  _ok()   { echo "\033[32m✔\033[0m $1"; }
  _warn() { echo "\033[33m⚠\033[0m $1"; }

  # Simple keys: vault title = env var, password field = value
  _simple_keys=(
    OLLAMA_CLOUD_API_KEY
    GITHUB_PERSONAL_ACCESS_TOKEN
    GITLAB_PERSONAL_ACCESS_TOKEN
    MODAL_API_KEY
    MOONSHOT_API_KEY
    MISTRAL_API_KEY
    OPENAI_API_KEY
    ZAI_API_KEY
    MINIMAX_API_KEY
    OPENROUTER_API_KEY
    NPM_TOKEN
  )
  for _k in "${_simple_keys[@]}"; do
    _v="$(_pass_field "$_k" password)"
    if [[ -n "$_v" ]]; then
      _emit "$_k" "$_v"
      _ok "Pulled ${_k}"
    else
      _warn "Skipped ${_k} (not found)"
    fi
  done

  # Docker registries: pull credentials and login
  _docker_registries=(INFRA MARKETPLACE MYACCOUNT)
  for _name in "${_docker_registries[@]}"; do
    _url="$(_pass_field "DOCKER_REGISTRY_${_name}" url)"
    _u="$(_pass_field "DOCKER_REGISTRY_${_name}" username)"
    _p="$(_pass_field "DOCKER_REGISTRY_${_name}" password)"
    if [[ -n "$_u" && -n "$_p" ]]; then
      _emit "DOCKER_USER_${_name}" "$_u"
      _emit "DOCKER_PASSWORD_${_name}" "$_p"
      _ok "Pulled DOCKER_REGISTRY_${_name}"
      if command -v docker >/dev/null 2>&1 && [[ -n "$_url" ]]; then
        if ! echo "$_p" | docker login "$_url" -u "$_u" --password-stdin 2>&1 | grep -q "Login Succeeded"; then
          _warn "Docker login failed: $_url (check credentials and registry availability)"
        else
          _ok "Docker login: $_url"
        fi
      fi
    elif [[ -n "$_u" || -n "$_p" ]]; then
      _warn "Partial credentials for DOCKER_REGISTRY_${_name}"
    else
      _warn "Skipped DOCKER_REGISTRY_${_name}"
    fi
  done

  unset _k _v _u _p _url _name _simple_keys _docker_registries
  unset -f _pass_field _emit _ok _warn
fi
eval "$("${HOME}/.local/bin/mise" activate zsh)"

export PATH="/opt/homebrew/opt/libxml2/bin:${HOME}/.local/share/mise/shims:${HOME}/.bun/bin:$PATH"

eval "$(starship init zsh)"

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# opencode
export PATH="${HOME}/.opencode/bin:/usr/local/bin:${HOME}/bin:$PATH"

# Fix TERM for SSH connections to servers without ghostty terminfo
alias ssh='TERM=xterm-256color ssh'

# bun completions
[ -s "${HOME}/.bun/_bun" ] && source "${HOME}/.bun/_bun"

export PATH="/opt/homebrew/opt/trash/bin:$PATH"

# Upgrade all AI coding tools in one shot
upgrade-ai() {
  claude upgrade
  opencode upgrade
  kilo upgrade
  npm install -g @openai/codex @mariozechner/pi-coding-agent @indykish/oracle
}

# freetype/reportlab build flags (macOS)
export CFLAGS="-I/opt/homebrew/include/freetype2"
export CPPFLAGS="-I/opt/homebrew/include/freetype2"
export LDFLAGS="-L/opt/homebrew/lib"
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig"
