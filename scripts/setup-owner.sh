#!/usr/bin/env bash
# 🎨 setup-owner.sh - Personalize AGENTS.md with your details

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 🌈 Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 📝 Get user input
get_email() {
	local git_email
	git_email=$(git config --global user.email 2>/dev/null || echo "")

	if [[ -n "$git_email" ]]; then
		echo -e "${BLUE}📧 Found git email:${NC} $git_email"
		read -rp "Use this? [Y/n]: " use_git
		[[ "${use_git:-Y}" =~ ^[Yy]$ ]] && {
			echo "$git_email"
			return
		}
	fi

	local email=""
	while [[ -z "$email" ]]; do
		read -rp "${YELLOW}📧 Enter your email:${NC} " email
	done
	echo "$email"
}

ask() {
	read -rp "${BLUE}$1${NC} [$2]: " val
	echo "${val:-$2}"
}

# 🔧 Update files
update_files() {
	local name="$1" handle="$2" discord="$3" email="$4" hardware="$5"

	# Update AGENTS.md
	sed -i '' \
		-e "s/{{OWNER_NAME}}/$name/g" \
		-e "s/{{OWNER_HANDLE}}/$handle/g" \
		-e "s/{{DISCORD_HANDLE}}/$discord/g" \
		-e "s/{{OWNER_EMAIL}}/$email/g" \
		-e "s/{{HARDWARE}}/$hardware/g" \
		-e '/> \*\*Setup Required\*\*: Run/d' \
		"$ROOT_DIR/AGENTS.md"

	# Update runbooks
	if [[ -f "$ROOT_DIR/runbooks/docs/mac-vm.md" ]]; then
		sed -i '' \
			-e "s/{{OWNER_EMAIL}}/$email/g" \
			-e '/> \*\*Setup Required\*\*: Configure/d' \
			"$ROOT_DIR/runbooks/docs/mac-vm.md"
	fi
}

# 🚀 Main
echo -e "${GREEN}🎨 Setting up owner profile...${NC}\n"

email=$(get_email)
name=$(ask "👤 Name" "Anonymous")
handle=$(ask "🔗 GitHub/GitLab" "@username")
discord=$(ask "💬 Discord (optional)" "-")
hardware=$(ask "💻 Hardware" "MacBook")

echo -e "\n${YELLOW}📝 Updating files...${NC}"
update_files "$name" "$handle" "$discord" "$email" "$hardware"

echo -e "\n${GREEN}✅ Done!${NC}"
echo "  👤 $name | 🔗 $handle"
echo "  💬 $discord | 📧 $email"
echo "  💻 $hardware"
