#!/usr/bin/env bash
# 🚀 run.sh - Deploy agent profiles, configs & skills

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 🎨 Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 📁 Config mappings (src:dst:desc)
CONFIGS=(
	".config/opencode/opencode.json:$HOME/.config/opencode/opencode.json:🤖 OpenCode"
	".config/kilo/opencode.json:$HOME/.config/kilo/opencode.json:🔥 KiloCode"
	".pi/agent/auth.json:$HOME/.pi/agent/auth.json:🔐 Pi auth"
	".pi/agent/models.json:$HOME/.pi/agent/models.json:📊 Pi models"
	".pi/agent/settings.json:$HOME/.pi/agent/settings.json:⚙️  Pi settings"
	".claude/settings.json:$HOME/.claude/settings.json:🎯 Claude"
	".claude-e2e/settings.json:$HOME/.claude-e2e/settings.json:🧪 Claude E2E"
)

# 👥 Agents (name:home:profile:skills)
AGENTS=(
	"claude:$HOME/.claude:CLAUDE.md:commands"
	"claude-e2e:$HOME/.claude-e2e:CLAUDE.md:commands"
	"codex:$HOME/.codex:AGENTS.md:skills"
	"opencode:$HOME/.opencode:AGENTS.md:skills"
	"ampcode:$HOME/.ampcode:AGENTS.md:skills"
	"kilocode:$HOME/.kilocode:AGENTS.md:skills"
	"agents:$HOME/.config/agents:AGENTS.md:skills"
	"pi:$HOME/.pi/agent:AGENTS.md:skills"
)

# 🗑️ Stale skills to remove
STALE=(backend-review frontend-review python-backend-scaffold rust-scaffold go-scaffold)

CLEAN=0
SKILLS=()

# 🔧 Utils
log() { echo -e "  ${GREEN}✓${NC} $1"; }
section() { echo -e "\n${BLUE}$1${NC}"; }

# 📦 Collect skills
collect_skills() {
	SKILLS=()
	while IFS= read -r -d '' skill; do
		SKILLS+=("$(basename "$skill")")
	done < <(find "$ROOT_DIR/skills" -maxdepth 1 -mindepth 1 -type d -exec test -f '{}/SKILL.md' \; -print0 | sort -z)
}

# 🔗 Clean stale symlinks
clean_symlinks() {
	local dir="${1:?directory required}"
	[[ -d "$dir" ]] || return
	local f t
	for f in "$dir"/*; do
		[[ -L "$f" ]] || continue
		t=$(readlink "$f")
		[[ "$t" == */.config/e2e/ai-jumpstart/* ]] && rm -f "$f" && log "cleaned: $(basename "$f")"
	done
}

# 🎯 Deploy configs
deploy_configs() {
	section "📦 Deploying configs..."
	local entry src dst desc
	for entry in "${CONFIGS[@]}"; do
		IFS=: read -r src dst desc <<<"$entry"
		[[ -f "$ROOT_DIR/$src" ]] || continue
		mkdir -p "$(dirname "$dst")"
		cp "$ROOT_DIR/$src" "$dst"
		log "$desc"
	done

        # Bootstrap ~/.zshrc and ask before replacing an existing user config.
        if [[ -f "$ROOT_DIR/.zshrc" ]]; then
                if [[ ! -f "$HOME/.zshrc" ]]; then
                        cp "$ROOT_DIR/.zshrc" "$HOME/.zshrc"
                        log "🐚 Zsh shell config (~/.zshrc)"
                elif [[ -t 0 ]]; then
                        local install_zshrc backup
                        echo -e "  ${YELLOW}⚠️  ~/.zshrc already exists. The dotfiles version is opinionated.${NC}"
                        read -rp "   Install dotfiles .zshrc and replace existing one? [y/N]: " install_zshrc
                        if [[ "${install_zshrc:-N}" =~ ^[Yy]$ ]]; then
                                backup="$HOME/.zshrc.bak.$(date +%Y%m%d-%H%M%S)"
                                cp "$HOME/.zshrc" "$backup"
                                cp "$ROOT_DIR/.zshrc" "$HOME/.zshrc"
                                log "🐚 Zsh shell config (~/.zshrc) [backup: $backup]"
                        else
                                log "🐚 Skipped ~/.zshrc (kept existing file)"
                        fi
                else
                        log "🐚 Skipped ~/.zshrc (non-interactive shell and file already exists)"
                fi
        fi
}

# 👤 Deploy to agent
deploy_agent() {
	local name="$1" home="${2:?home required}" profile="$3" skills_dir="${4:?skills_dir required}"
	[[ -d "$home" ]] || return

	mkdir -p "$home/$skills_dir"
	clean_symlinks "$home/$skills_dir"

	# Remove stale skills
	local stale
	for stale in "${STALE[@]}"; do
		rm -rf "${home:?}/${skills_dir:?}/${stale}" "${home:?}/${skills_dir:?}/${stale}.md" 2>/dev/null || true
	done

	# Clean mode
	if ((CLEAN)); then
		rm -f "$home/$profile"
		local s
		for s in "${SKILLS[@]}"; do rm -rf "${home:?}/${skills_dir:?}/${s}" "${home:?}/${skills_dir:?}/${s}.md"; done
	fi

	# Copy profile
	if [[ "$profile" == "CLAUDE.md" ]]; then
		cp "$ROOT_DIR/CLAUDE.md" "$home/$profile"
	else
		cp "$ROOT_DIR/AGENTS.md" "$home/$profile"
	fi

	# Label profile
	local label="$name"
	[[ "$name" == "claude" ]] && label="Claude"
	[[ "$name" == "claude-e2e" ]] && label="Claude E2E"
	perl -0pi -e "s/^# Oracle Operating Model.*/# Oracle Operating Model ($label Profile)/" "$home/$profile"

	# Copy skills
	local s
	for s in "${SKILLS[@]}"; do
		if [[ -d "$ROOT_DIR/skills/$s" ]]; then
			rm -rf "${home:?}/${skills_dir:?}/${s}" "${home:?}/${skills_dir:?}/${s}.md"
			cp -R "$ROOT_DIR/skills/$s" "$home/$skills_dir/$s"
		fi
	done

	log "$name"
}

# 🎬 Main
main() {
	cd "$ROOT_DIR"
	local version
	version=$(cat "$ROOT_DIR/VERSION" 2>/dev/null || echo "unknown")
	echo -e "${YELLOW}🚀 ai-jumpstart v${version}${NC}"

	# Parse args
	while (($#)); do
		case "$1" in
		--clean) CLEAN=1 ;;
		-h | --help)
			echo "Usage: ./run.sh [--clean]"
			exit 0
			;;
		*)
			echo "Unknown: $1"
			exit 1
			;;
		esac
		shift
	done

	# 🔍 Check for unset owner placeholders
	if grep -q '{{OWNER_NAME}}' "$ROOT_DIR/AGENTS.md" 2>/dev/null; then
		echo -e "\n${YELLOW}⚠️  Your name, email, and handle have not been set up yet.${NC}"
		read -rp "   Would you like to provide your details now? [Y/n]: " run_setup
		if [[ "${run_setup:-Y}" =~ ^[Yy]$ ]]; then
			bash "$ROOT_DIR/scripts/setup-owner.sh"
		else
			echo -e "   ${YELLOW}Skipping. Run ./scripts/setup-owner.sh when ready.${NC}"
		fi
	fi

	collect_skills
	deploy_configs

	section "👥 Deploying to agents..."
	local entry name home profile skills_dir
	for entry in "${AGENTS[@]}"; do
		IFS=: read -r name home profile skills_dir <<<"$entry"
		deploy_agent "$name" "$home" "$profile" "$skills_dir"
	done

	echo -e "\n${GREEN}✅ Done!${NC} Skills: ${#SKILLS[@]}"
	echo -e "${YELLOW}💡 Reminder:${NC} Set API keys in ~/.zshrc"
}

main "$@"
