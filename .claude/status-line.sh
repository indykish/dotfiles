#!/bin/bash
# 📊 Claude Code Status Line - Shows project info + costs

# 🎨 Emojis
EMOJI_FOLDER="📁"
EMOJI_GIT="🌿"
EMOJI_WORKTREE="🌲"
EMOJI_MODEL="🤖"
EMOJI_VENV="💼"
EMOJI_PYTHON="🐍"
EMOJI_GO="🦫"
EMOJI_COST="💸"
EMOJI_DAILY="💰"
EMOJI_TIME="⏱️"

# 📂 Get folder name
get_folder() {
	basename "$(echo "$1" | jq -r '.workspace.current_dir')"
}

# 🤖 Get model name
get_model() {
	echo "$1" | jq -r '.model.display_name'
}

# 🌿 Get git branch
get_branch() {
	git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'main'
}

# 🌲 Get worktree name (non-empty only when in a linked worktree)
get_worktree() {
	local git_dir
	git_dir=$(git rev-parse --git-dir 2>/dev/null) || return
	if [[ "$git_dir" == *"/worktrees/"* ]]; then
		basename "$git_dir"
	fi
}

# 🐍 Get Python version
get_python() {
	python3 --version 2>/dev/null | cut -d' ' -f2 || echo ''
}

# 🦫 Get Go version
get_go() {
	go version 2>/dev/null | grep -oE 'go[0-9.]+' | sed 's/go//' || echo ''
}

# 🔍 Detect language info
detect_lang() {
	local folder="$1" info=""

	if [[ -n "${VIRTUAL_ENV:-}" ]]; then
		local venv="${VIRTUAL_ENV##*/}"
		venv=$(echo "$venv" | sed 's/-[0-9].*//')
		[[ "$venv" =~ ^(\.venv|venv)$ ]] && venv="$folder"
		info=" | $EMOJI_VENV ($venv) | $EMOJI_PYTHON $(get_python)"
	elif [[ -f "requirements.txt" || -f "pyproject.toml" || -f "setup.py" ]]; then
		info=" | $EMOJI_PYTHON $(get_python)"
	elif [[ -f "go.mod" ]] || ls *.go >/dev/null 2>&1; then
		local gv=$(get_go)
		[[ -n "$gv" ]] && info=" | $EMOJI_GO $gv"
	fi

	echo "$info"
}

# 💰 Get cost info
get_costs() {
	command -v bun >/dev/null 2>&1 || return

	local output
	output=$(echo "$1" | bun x ccusage statusline 2>/dev/null)
	[[ -z "$output" ]] && return

	local blocks session daily
	blocks=$(bun x ccusage blocks --active --json 2>/dev/null)
	session=$(echo "$output" | grep -oE '\$[0-9.]+ session' | sed 's/ session//' | head -1)
	daily=$(echo "$output" | grep -oE '\$[0-9.]+ today' | sed 's/ today//' | head -1)

	if [[ -n "$blocks" ]]; then
		local cost
		cost=$(echo "$blocks" | jq -r '.blocks[0].costUSD // empty')
		if [[ -n "$cost" && "$cost" != "null" ]]; then
			session="$"$(printf '%.2f' "$cost")
		fi
	fi

	local parts=()
	[[ -n "$session" && "$session" != "N/A" ]] && parts+=("$EMOJI_COST $session")
	[[ -n "$daily" ]] && parts+=("$EMOJI_DAILY $daily/day")

	[[ ${#parts[@]} -gt 0 ]] && echo " | ${parts[*]}"
}

# 🚀 Main
main() {
	local input=$(cat)
	local folder=$(get_folder "$input")
	local model=$(get_model "$input")
	local branch=$(get_branch)
	local worktree=$(get_worktree)
	local lang=$(detect_lang "$folder")
	local cost=$(get_costs "$input")

	local wt_part=""
	[[ -n "$worktree" ]] && wt_part=" | $EMOJI_WORKTREE $worktree"

	echo "$EMOJI_FOLDER $folder$lang | $EMOJI_GIT $branch$wt_part | $EMOJI_MODEL $model$cost"
}

main
