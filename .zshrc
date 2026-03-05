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
if command -v mysql_config >/dev/null 2>&1; then
  export MYSQLCLIENT_CFLAGS="$(mysql_config --cflags)"
  export MYSQLCLIENT_LDFLAGS="$(mysql_config --libs)"
fi
export GOPATH="${HOME}/code/go"

export GPG_KEY_ID=72980C0F4BF701C8

E2E_AGENT_PROFILES_DIR="${HOME}/.config/clawable"
AGENT_ENV="${AGENT_ENV:-local}"
E2E_AGENT_ENV_FILE="${E2E_AGENT_PROFILES_DIR}/.env_mac.${AGENT_ENV}"
CLAWABLE_ENV_FILE="${E2E_AGENT_PROFILES_DIR}/.env_mac_clawable.${AGENT_ENV}"

_env_ok() { printf '\033[32m✔\033[0m %s\n' "$1"; }
_env_warn() { printf '\033[33m⚠\033[0m %s\n' "$1"; }

_source_env_file() {
  local env_file="$1"
  if [[ -f "${env_file}" ]]; then
    set -a
    source "${env_file}"
    set +a
    _env_ok "Found ${env_file}"
    return 0
  fi
  return 1
}

_pass_field() {
  pass-cli item view --vault-name "$1" --item-title "$2" --field "$3" 2>/dev/null
}

_emit_export() {
  local env_file="$1"
  local key="$2"
  local value="$3"
  printf 'export %s=%q\n' "${key}" "${value}" >> "${env_file}"
  export "${key}=${value}"
}

_init_env_file() {
  local env_dir="$1"
  local env_file="$2"
  mkdir -p "${env_dir}"
  : > "${env_file}"
  chmod 600 "${env_file}"
}

_manifest_keys() {
  local vault="$1"
  local item_title="${2:-AGENT_KEYS}"
  local item_field="${3:-password}"
  local raw key

  raw="$(_pass_field "${vault}" "${item_title}" "${item_field}")"
  [[ -z "${raw}" ]] && return 0

  raw="${raw//$'\r'/ }"
  raw="${raw//$'\n'/ }"
  raw="${raw//,/ }"

  for key in ${=raw}; do
    [[ -z "${key}" ]] && continue
    [[ "${key}" == \#* ]] && continue
    printf '%s\n' "${key}"
  done
}

_pull_simple_keys_from_vault() {
  local vault="$1"
  local env_file="$2"
  shift 2

  local key value
  for key in "$@"; do
    value="$(_pass_field "${vault}" "${key}" password)"
    if [[ -n "${value}" ]]; then
      _emit_export "${env_file}" "${key}" "${value}"
      _env_ok "Pulled ${key}"
    else
      _env_warn "Skipped ${key} (not found in ${vault})"
    fi
  done
}

load-buffet-env() {
  local vault="AGENTS_BUFFET"
  local key_manifest="AGENT_KEYS"
  local -a simple_keys docker_registries
  local name url user password

  if _source_env_file "${E2E_AGENT_ENV_FILE}"; then
    return 0
  fi

  if ! command -v pass-cli >/dev/null 2>&1; then
    _env_warn "pass-cli not found; cannot generate ${E2E_AGENT_ENV_FILE}"
    return 1
  fi

  local -a simple_keys
  simple_keys=("${(@f)$(_manifest_keys "${vault}" "${key_manifest}" password)}")

  if (( ${#simple_keys[@]} == 0 )); then
    _env_warn "AGENT_KEYS not found in ${vault}; skipping ${E2E_AGENT_ENV_FILE} generation"
    return 1
  fi

  _env_ok "Loaded ${#simple_keys[@]} keys from ${vault}/${key_manifest}"
  _init_env_file "${E2E_AGENT_PROFILES_DIR}" "${E2E_AGENT_ENV_FILE}"
  _pull_simple_keys_from_vault "${vault}" "${E2E_AGENT_ENV_FILE}" "${simple_keys[@]}"

  docker_registries=(INFRA MARKETPLACE MYACCOUNT)
  for name in "${docker_registries[@]}"; do
    url="$(_pass_field "${vault}" "DOCKER_REGISTRY_${name}" url)"
    user="$(_pass_field "${vault}" "DOCKER_REGISTRY_${name}" username)"
    password="$(_pass_field "${vault}" "DOCKER_REGISTRY_${name}" password)"
    if [[ -n "${user}" && -n "${password}" ]]; then
      _emit_export "${E2E_AGENT_ENV_FILE}" "DOCKER_USER_${name}" "${user}"
      _emit_export "${E2E_AGENT_ENV_FILE}" "DOCKER_PASSWORD_${name}" "${password}"
      _env_ok "Pulled DOCKER_REGISTRY_${name}"
      if command -v docker >/dev/null 2>&1 && [[ -n "${url}" ]]; then
        if ! printf '%s' "${password}" | docker login "${url}" -u "${user}" --password-stdin 2>&1 | grep -q "Login Succeeded"; then
          _env_warn "Docker login failed: ${url} (check credentials and registry availability)"
        else
          _env_ok "Docker login: ${url}"
        fi
      fi
    elif [[ -n "${user}" || -n "${password}" ]]; then
      _env_warn "Partial credentials for DOCKER_REGISTRY_${name}"
    else
      _env_warn "Skipped DOCKER_REGISTRY_${name}"
    fi
  done
}

load-clawable-env() {
  CLAWABLE_ENV_FILE="${E2E_AGENT_PROFILES_DIR}/.env_mac_clawable.${AGENT_ENV}"
  local vault="CLW_${(U)AGENT_ENV}"

  if _source_env_file "${CLAWABLE_ENV_FILE}"; then
    return 0
  fi

  if ! command -v pass-cli >/dev/null 2>&1; then
    _env_warn "pass-cli not found; cannot generate ${CLAWABLE_ENV_FILE}"
    return 1
  fi

  local -a keys
  keys=("${(@f)$(_manifest_keys "${vault}" AGENT_KEYS password)}")

  if (( ${#keys[@]} == 0 )); then
    _env_warn "AGENT_KEYS not found in ${vault}; skipping"
    return 1
  fi

  _env_ok "AGENT_ENV=${AGENT_ENV} → vault ${vault} (${#keys[@]} keys)"
  _init_env_file "${E2E_AGENT_PROFILES_DIR}" "${CLAWABLE_ENV_FILE}"
  _pull_simple_keys_from_vault "${vault}" "${CLAWABLE_ENV_FILE}" "${keys[@]}"
  _env_ok "Created ${CLAWABLE_ENV_FILE}"
}

load-buffet-env || true
load-clawable-env || true

if [[ -x "${HOME}/.local/bin/mise" ]]; then
  eval "$("${HOME}/.local/bin/mise" activate zsh)"
fi

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
  echo "🤖 Upgrading claude..."
  claude upgrade
  echo "🤖 Upgrading opencode..."
  opencode upgrade
  echo "🤖 Upgrading kilo..."
  kilo upgrade
  echo "🤖 Upgrading amp..."
  amp update
  echo "📦 Upgrading npm packages: @openai/codex, @mariozechner/pi-coding-agent, @indykish/oracle..."
  npm install -g @openai/codex @mariozechner/pi-coding-agent @indykish/oracle
  echo "📦 Upgrading bun package: @tobilu/qmd..."
  bun install -g @tobilu/qmd
  echo "✅ All AI coding tools upgraded!"
}

# freetype/reportlab build flags (macOS)
export CFLAGS="-I/opt/homebrew/include/freetype2"
export CPPFLAGS="-I/opt/homebrew/include/freetype2"
export LDFLAGS="-L/opt/homebrew/lib"
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig"
