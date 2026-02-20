#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# ── Agent home directories ──────────────────────────────────────────
# Each entry: agent_name:home_dir:profile_filename:skills_dir
AGENT_MAP=(
  "claude:$HOME/.claude:CLAUDE.md:commands"
  "claude-e2e:$HOME/.claude-e2e:CLAUDE.md:commands"
  "codex:$HOME/.codex:AGENTS.md:skills"
  "opencode:$HOME/.opencode:AGENTS.md:skills"
  "ampcode:$HOME/.ampcode:AGENTS.md:skills"
  "kilocode:$HOME/.kilocode:AGENTS.md:skills"
  "agents:$HOME/.config/agents:AGENTS.md:skills"
  "pi:$HOME/.pi/agent:AGENTS.md:skills"
)

# ── Config file mappings ─────────────────────────────────────────────
# Format: source_path:destination_path:description
CONFIG_MAP=(
  "$ROOT_DIR/.claude/settings.json:$HOME/.claude/settings.json:Claude Code settings"
  "$ROOT_DIR/.claude-e2e/settings.json:$HOME/.claude-e2e/settings.json:Claude E2E settings"
  "$ROOT_DIR/.codex/config.toml:$HOME/.codex/config.toml:Codex config"
  "$ROOT_DIR/.config/opencode/opencode.json:$HOME/.config/opencode/opencode.json:OpenCode config"
  "$ROOT_DIR/.config/amp/settings.json:$HOME/.config/amp/settings.json:Amp settings"
  "$ROOT_DIR/.config/kilo/opencode.json:$HOME/.config/kilo/opencode.json:KiloCode config"
)

AGENT_PROFILE_CONFIG_DIR="$HOME/.config/e2e/agent-profiles"
AGENT_PROFILE_SRC_DIR="$ROOT_DIR/.config/e2e/agent-profile"
AGENT_PROFILE_ENV_SRC="$AGENT_PROFILE_SRC_DIR/.env.example"
AGENT_PROFILE_ZOHO_SRC="$AGENT_PROFILE_SRC_DIR/zoho.json.example"
AGENT_PROFILE_ZOHO_DESK_SRC="$AGENT_PROFILE_SRC_DIR/zoho-desk.json.example"

# ── Skills removed from the catalog (delete from agent dirs) ────────
# Add names here when a skill is deleted from skills/
STALE_SKILLS=(
  "backend-review"
  "frontend-review"
  "python-backend-scaffold"
  "rust-scaffold"
  "go-scaffold"
  "typescript-bun-scaffold"
  "javascript-cli-scaffold"
  "desktop-tauri-scaffold"
  "mobile-react-native-scaffold"
)

# ── Collect skill entries ────────────────────────────────────────────
SKILL_NAMES=()
while IFS= read -r skill; do
  SKILL_NAMES+=("$skill")
done < <(
  find "$ROOT_DIR/skills" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/SKILL.md' ';' -exec basename {} \; | sort -u
)

# ── Deploy config files ──────────────────────────────────────────────
deploy_configs() {
  echo "Deploying agent configuration files..."
  echo ""
  
  for entry in "${CONFIG_MAP[@]}"; do
    IFS=: read -r src dst desc <<< "$entry"
    if [[ -f "$src" ]]; then
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
      echo "  ✓ $desc → $dst"
    else
      echo "  ⚠ $desc not found at $src"
    fi
  done
  echo ""
}

# ── Ensure shared config files exist (do not overwrite) ─────────────
mkdir -p "$AGENT_PROFILE_CONFIG_DIR"

if [[ -f "$AGENT_PROFILE_ENV_SRC" ]]; then
  if [[ ! -f "$AGENT_PROFILE_CONFIG_DIR/.env.example" ]]; then
    cp "$AGENT_PROFILE_ENV_SRC" "$AGENT_PROFILE_CONFIG_DIR/.env.example"
    echo "  ✓ agent profiles → $AGENT_PROFILE_CONFIG_DIR/.env.example"
  fi
fi

if [[ -f "$AGENT_PROFILE_ZOHO_SRC" ]]; then
  if [[ ! -f "$AGENT_PROFILE_CONFIG_DIR/zoho.json.example" ]]; then
    cp "$AGENT_PROFILE_ZOHO_SRC" "$AGENT_PROFILE_CONFIG_DIR/zoho.json.example"
    echo "  ✓ agent profiles → $AGENT_PROFILE_CONFIG_DIR/zoho.json.example"
  fi
fi

if [[ -f "$AGENT_PROFILE_ZOHO_DESK_SRC" ]]; then
  if [[ ! -f "$AGENT_PROFILE_CONFIG_DIR/zoho-desk.json.example" ]]; then
    cp "$AGENT_PROFILE_ZOHO_DESK_SRC" "$AGENT_PROFILE_CONFIG_DIR/zoho-desk.json.example"
    echo "  ✓ agent profiles → $AGENT_PROFILE_CONFIG_DIR/zoho-desk.json.example"
  fi
fi

# ── Parse flags ─────────────────────────────────────────────────────
CLEAN=0

while (($#)); do
  case "$1" in
    --clean)
      CLEAN=1
      ;;
    -h|--help)
      cat << 'EOF'
Usage:
  ./scripts/run.sh [--clean]

Options:
  --clean   Remove ai-jumpstart-managed files before syncing.

Deploys agent configs, profiles (AGENTS.md/CLAUDE.md), and skills into each
agent's home directory (~/.claude, ~/.codex, etc.).
Only replaces files managed by ai-jumpstart; user files are untouched.
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

# ── Helper: profile label per agent ────────────────────────────────
profile_label() {
  case "$1" in
    claude)     echo "Claude Profile" ;;
    claude-e2e) echo "Claude E2E Profile" ;;
    codex)      echo "Codex Profile" ;;
    opencode)   echo "OpenCode Profile" ;;
    ampcode)    echo "AmpCode Profile" ;;
    kilocode)   echo "KiloCode Profile" ;;
    agents)     echo "Agents Profile" ;;
    pi)         echo "Pi Profile" ;;
    *)          echo "$1 Profile" ;;
  esac
}

# ── Skill copy helper ───────────────────────────────────────────────
copy_skill_entry() {
  local skill_name="$1" target_dir="$2"
  local src_dir="$ROOT_DIR/skills/$skill_name"
  local dst_dir="$target_dir/$skill_name"
  local dst_file="$target_dir/$skill_name.md"

  if [[ -d "$src_dir" && -f "$src_dir/SKILL.md" ]]; then
    rm -rf "$dst_dir"
    rm -f "$dst_file"
    cp -R "$src_dir" "$dst_dir"
    return 0
  fi
}

# ── Remove stale symlinks from previous ai-jumpstart installs ───────
clean_stale_symlinks() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  local removed=0
  for f in "$dir"/*; do
    [[ -L "$f" ]] || continue
    local target
    target="$(readlink "$f")"
    # Remove symlinks pointing to old ~/.config/e2e/ai-jumpstart/ location
    if [[ "$target" == */.config/e2e/ai-jumpstart/* ]]; then
      rm -f "$f"
      echo "    removed stale symlink: $(basename "$f") → $target"
      ((removed++)) || true
    fi
  done
  return 0
}

# ── Deploy to one agent ─────────────────────────────────────────────
deploy_agent() {
  local agent="$1" home="$2" profile="$3" skills_dir="$4"

  # Skip if home directory doesn't exist (optional agents only)
  if [[ ! -d "$home" ]]; then
    return 0
  fi

  mkdir -p "$home/$skills_dir"

  # -- Remove stale symlinks from previous installs --
  clean_stale_symlinks "$home/$skills_dir"
  # Also check if profile itself is a stale symlink
  if [[ -L "$home/$profile" ]]; then
    local target
    target="$(readlink "$home/$profile")"
    if [[ "$target" == */.config/e2e/ai-jumpstart/* ]]; then
      rm -f "$home/$profile"
      echo "    removed stale symlink: $profile → $target"
    fi
  fi

  # -- Remove known stale skills --
  for stale in "${STALE_SKILLS[@]}"; do
    if [[ -f "$home/$skills_dir/$stale.md" ]]; then
      rm -f "$home/$skills_dir/$stale.md"
      echo "    removed stale skill: $stale.md"
    fi
    if [[ -d "$home/$skills_dir/$stale" ]]; then
      rm -rf "$home/$skills_dir/$stale"
      echo "    removed stale skill dir: $stale"
    fi
  done

  # -- Clean: remove only our managed files --
  if (( CLEAN )); then
    rm -f "$home/$profile"
    for skill in "${SKILL_NAMES[@]}"; do
      rm -rf "$home/$skills_dir/$skill"
      rm -f "$home/$skills_dir/$skill.md"
    done
  fi

  # -- Copy profile (AGENTS.md or CLAUDE.md) --
  if [[ "$profile" == "CLAUDE.md" ]]; then
    cp "$ROOT_DIR/CLAUDE.md" "$home/$profile"
  else
    cp "$ROOT_DIR/AGENTS.md" "$home/$profile"
  fi

  # -- Stamp profile with agent label --
  local label
  label="$(profile_label "$agent")"
  perl -0pi -e "s/^# Oracle Operating Model(?: \\(.*\\))?/# Oracle Operating Model ($label)/" "$home/$profile"

  # -- Copy skills (overwrite ours, leave user files alone) --
  for skill in "${SKILL_NAMES[@]}"; do
    copy_skill_entry "$skill" "$home/$skills_dir"
  done

  echo "  ✓ $agent → $home"
}

# ── Verification ────────────────────────────────────────────────────
verify_zoho_files() {
  echo ""
  echo "Verifying Zoho integration files..."
  local all_ok=true
  
  # Check zoho-desk.json.example exists in source
  if [[ ! -f "$AGENT_PROFILE_ZOHO_DESK_SRC" ]]; then
    echo "  ⚠ zoho-desk.json.example missing from $AGENT_PROFILE_SRC_DIR"
    all_ok=false
  else
    echo "  ✓ zoho-desk.json.example exists in source"
  fi
  
  # Check if zoho-desk.mjs exists in scripts
  if [[ ! -f "$ROOT_DIR/scripts/zoho-desk.mjs" ]]; then
    echo "  ⚠ zoho-desk.mjs missing from scripts/"
    all_ok=false
  else
    echo "  ✓ zoho-desk.mjs exists"
  fi
  
  # Check if zoho-sprint.mjs exists in scripts
  if [[ ! -f "$ROOT_DIR/scripts/zoho-sprint.mjs" ]]; then
    echo "  ⚠ zoho-sprint.mjs missing from scripts/"
    all_ok=false
  else
    echo "  ✓ zoho-sprint.mjs exists"
  fi
  
  # Check deployed files - if actual config exists, we're good; otherwise check for examples
  if [[ -f "$AGENT_PROFILE_CONFIG_DIR/zoho.json" ]]; then
    echo "  ✓ zoho.json configured"
  elif [[ -f "$AGENT_PROFILE_CONFIG_DIR/zoho.json.example" ]]; then
    echo "  ✓ zoho.json.example deployed (zoho.json not yet configured)"
  else
    echo "  ⚠ zoho.json.example not deployed to $AGENT_PROFILE_CONFIG_DIR"
    all_ok=false
  fi
  
  if [[ -f "$AGENT_PROFILE_CONFIG_DIR/zoho-desk.json" ]]; then
    echo "  ✓ zoho-desk.json configured"
  elif [[ -f "$AGENT_PROFILE_CONFIG_DIR/zoho-desk.json.example" ]]; then
    echo "  ✓ zoho-desk.json.example deployed (zoho-desk.json not yet configured)"
  else
    echo "  ⚠ zoho-desk.json.example not deployed to $AGENT_PROFILE_CONFIG_DIR"
    all_ok=false
  fi
  
  if $all_ok; then
    echo "  ✓ All Zoho files verified"
  else
    echo "  ⚠ Some Zoho files are missing"
  fi
  echo ""
}

# ── Main ────────────────────────────────────────────────────────────
echo "Deploying agent profiles + skills..."
echo ""

# Deploy configs first
deploy_configs

# Then deploy profiles and skills
for entry in "${AGENT_MAP[@]}"; do
  IFS=: read -r agent home profile skills_dir <<< "$entry"
  deploy_agent "$agent" "$home" "$profile" "$skills_dir"
done

# Verify Zoho files
verify_zoho_files

echo ""
echo "Done. Skills deployed: ${SKILL_NAMES[*]}"
echo ""
echo "Note: If you don't use pass-cli, set API key env vars manually in ~/.zshrc or your shell profile:"
echo "  OLLAMA_CLOUD_API_KEY GITHUB_PERSONAL_ACCESS_TOKEN GITLAB_PERSONAL_ACCESS_TOKEN"
echo "  MODAL_API_KEY MOONSHOT_API_KEY OPENAI_API_KEY ZAI_API_KEY Z_AI_API_KEY ZAI_MCP_AUTH_TOKEN"
