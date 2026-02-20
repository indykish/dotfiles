#!/bin/bash
# 🧪 Claude Code E2E Status Line - Shows project info + costs [E2E]

source "$(dirname "$0")/status-line.sh" 2>/dev/null || true

# 🧪 E2E indicator
E2E_BADGE="| 🧪 E2E"

# 🚀 Main (override)
main() {
	local input=$(cat)
	local folder=$(get_folder "$input")
	local model=$(get_model "$input")
	local branch=$(get_branch)
	local lang=$(detect_lang "$folder")
	local cost=$(get_costs "$input")

	echo "📁 $folder$lang | 🌿 $branch | 🤖 $model$cost $E2E_BADGE"
}

main
