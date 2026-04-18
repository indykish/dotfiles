#!/bin/bash
# Claude Code Status Line - Shows project info + costs + context + rate limits

# Emojis
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
EMOJI_CTX="🧠"
EMOJI_RATE="⚡"

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

# 🌲 Get worktree indicator — non-empty when not in the canonical repo dir.
# Strategy: compare the session's current_dir basename against the git toplevel
# basename. If they differ (e.g. usezombie-m28-webhook-auth vs usezombie), show
# the current_dir basename so the worktree suffix is always visible.
get_worktree() {
	local input="$1"
	local session_dir
	session_dir=$(echo "$input" | jq -r '.workspace.current_dir // empty')
	[[ -z "$session_dir" ]] && return

	# Also check via git internals for linked worktrees
	local git_dir
	git_dir=$(git -C "$session_dir" rev-parse --git-dir 2>/dev/null)
	if [[ "$git_dir" == *"/worktrees/"* ]]; then
		basename "$session_dir"
		return
	fi

	# Fall back: compare session dir basename to git toplevel basename
	local toplevel
	toplevel=$(git -C "$session_dir" rev-parse --show-toplevel 2>/dev/null)
	[[ -z "$toplevel" ]] && return
	local sess_base top_base
	sess_base=$(basename "$session_dir")
	top_base=$(basename "$toplevel")
	if [[ "$sess_base" != "$top_base" ]]; then
		echo "$sess_base"
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

format_token_count() {
	local count="$1"

	[[ -z "$count" || "$count" == "null" ]] && return

	if (( count >= 1000000 )); then
		awk -v count="$count" 'BEGIN {
			value = count / 1000000;
			if (value == int(value)) {
				printf "%dM", value;
			} else {
				printf "%.1fM", value;
			}
		}'
	elif (( count >= 1000 )); then
		awk -v count="$count" 'BEGIN {
			value = count / 1000;
			if (value >= 100) {
				printf "%.0fk", value;
			} else if (value >= 10) {
				printf "%.0fk", value;
			} else {
				printf "%.1fk", value;
			}
		}' | sed 's/\.0k$/k/'
	else
		printf '%d' "$count"
	fi
}

# Get context window usage
get_context() {
	local input="$1"
	local current size used
	size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
	current=$(echo "$input" | jq -r '
		.context_window as $ctx
		| if ($ctx.current_usage | type) == "object" then
			(($ctx.current_usage.input_tokens // 0)
			+ ($ctx.current_usage.output_tokens // 0)
			+ ($ctx.current_usage.cache_creation_input_tokens // 0)
			+ ($ctx.current_usage.cache_read_input_tokens // 0))
		elif ($ctx.current_usage | type) == "number" then
			$ctx.current_usage
		elif ($ctx.used_percentage != null and $ctx.used_percentage > 0 and $ctx.context_window_size != null) then
			(($ctx.used_percentage * $ctx.context_window_size / 100) | floor)
		else
			empty
		end
	')
	[[ -z "$current" || -z "$size" ]] && return
	if [[ "$size" -gt 0 ]]; then
		used=$(awk -v current="$current" -v size="$size" 'BEGIN { printf "%.0f", (current / size) * 100 }')
	else
		used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
	fi

	local used_int current_fmt size_fmt
	used_int=$(printf '%.0f' "${used:-0}")
	current_fmt=$(format_token_count "$current")
	size_fmt=$(format_token_count "$size")

	# Color-code by usage: green < 50, yellow 50-79, red >= 80
	local color_start color_end
	if [[ "$used_int" -ge 80 ]]; then
		color_start="\033[31m"   # red
	elif [[ "$used_int" -ge 50 ]]; then
		color_start="\033[33m"   # yellow
	else
		color_start="\033[32m"   # green
	fi
	color_end="\033[0m"

	printf " | %s ctx:%b%s/%s%b" "$EMOJI_CTX" "$color_start" "$current_fmt" "$size_fmt" "$color_end"
}

# Get rate limit info (Claude.ai subscriptions only)
get_rate_limits() {
	local input="$1"
	local five_pct week_pct out=""

	five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
	week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

	[[ -z "$five_pct" && -z "$week_pct" ]] && return

	if [[ -n "$five_pct" ]]; then
		out="5h:$(printf '%.0f' "$five_pct")%"
	fi
	if [[ -n "$week_pct" ]]; then
		[[ -n "$out" ]] && out="$out "
		out="${out}7d:$(printf '%.0f' "$week_pct")%"
	fi

	echo " | $EMOJI_RATE $out"
}

# Get cost info
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

# Main
main() {
	local input
	input=$(cat)
	local folder
	folder=$(get_folder "$input")
	local model
	model=$(get_model "$input")
	local branch
	branch=$(get_branch)
	local worktree
	worktree=$(get_worktree "$input")
	local lang
	lang=$(detect_lang "$folder")
	local cost
	cost=$(get_costs "$input")
	local ctx
	ctx=$(get_context "$input")
	local rates
	rates=$(get_rate_limits "$input")

	local wt_part=""
	[[ -n "$worktree" ]] && wt_part=" | $EMOJI_WORKTREE $worktree"

	printf "%s %s%s | %s %s%s | %s %s%s%s%s\n" \
		"$EMOJI_FOLDER" "$folder" "$lang" \
		"$EMOJI_GIT" "$branch" "$wt_part" \
		"$EMOJI_MODEL" "$model" "$cost" "$ctx" "$rates"
}

main
