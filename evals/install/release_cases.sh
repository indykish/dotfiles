#!/usr/bin/env bash
# evals/install/release_cases.sh — CLI-surface and release-readiness behaviours.
#
# Sourced by run.sh alongside cases.sh; same discovery mechanism (install_*
# functions), split out at the length cap. Core materialisation lives in
# cases.sh — this file is the flag surface, the profile-default fallback, and
# the release artifacts (README, architecture doc, CI workflow).

# Refusing early is what keeps a half-installed tree from existing.
install_refuses_outside_a_repository() {
  local name="init outside a git work tree refuses and names the fix"
  local pkg sb; pkg="$(packed_root)"; sb="$(mk_sandbox)"
  if [[ -z "$pkg" ]]; then bad "$name" "npm pack or extract failed"; return; fi

  local out; out="$(run_packed "$pkg" "$sb" init)"
  if [[ "$out" != *"git init"* ]]; then bad "$name" "error does not name the fix: $out"; return; fi
  if [[ -e "$sb/AGENTS.md" ]]; then bad "$name" "wrote into a non-repository"; return; fi
  ok "$name"
}

# A stranger's repository is the common case: nothing to register, no name to
# pass. Pack selection reads the repository's own sources, so the Rust crate in
# the fixture receives the Rust façade and never the Zig one.
# The ruleset-authoring verbs operate on the engine's own sources; sync also
# repoints this machine's agent homes at the render. From a published payload
# that render sits in a package cache, so the links would resolve into a
# directory the package manager may delete.
install_authoring_verbs_refuse_from_a_published_payload() {
  local name="verify refuses from a published payload and names the install verbs"
  local pkg repo; pkg="$(packed_root)"; repo="$(mk_repo)"
  if [[ -z "$pkg" ]]; then bad "$name" "npm pack or extract failed"; return; fi

  local verb out code
  for verb in verify; do
    # shellcheck disable=SC2086
    out="$(run_packed "$pkg" "$repo" $verb 2>&1)"; code=$?
    if [[ "$code" -eq 0 ]]; then bad "$name" "$verb succeeded from a payload"; return; fi
    if [[ "$out" != *"orly init"* ]]; then bad "$name" "$verb did not name the install verbs: $out"; return; fi
  done

  # doctor keeps working: its install half is the consumer's business.
  out="$(run_packed "$pkg" "$repo" doctor 2>&1)"
  if [[ "$out" != *"orly init"* ]]; then bad "$name" "doctor did not report the missing install: $out"; return; fi
  if [[ "$out" == *"agent home"* ]]; then bad "$name" "doctor graded agent-home links from a payload: $out"; return; fi
  ok "$name"
}

install_selects_packs_from_repository_sources() {
  local name="init with no arguments selects packs from the repository's own sources"
  local pkg repo; pkg="$(packed_root)"; repo="$(mk_repo)"
  if [[ -z "$pkg" ]]; then bad "$name" "npm pack or extract failed"; return; fi

  local out; out="$(run_packed "$pkg" "$repo" init)"
  if [[ "$out" != *"written"* ]]; then bad "$name" "init did not report a materialisation: $out"; return; fi
  [[ -f "$repo/dispatch/write_rust.md" ]] || { bad "$name" "the Rust source did not select the Rust façade"; return; }
  [[ -f "$repo/dispatch/write_zig.md" ]] && { bad "$name" "a Zig façade was installed into a repository with no Zig"; return; }
  [[ -f "$repo/.oracle/orly.json" ]] || { bad "$name" "init did not seed .oracle/orly.json"; return; }
  ok "$name"
}

# `sync` and `render` are gone: `orly update` covers the engine checkout now
# that same-path pack sources are skipped, and the preview rides on the command
# being previewed. Deleted, not aliased (RULE NDC — no compatibility spellings).
install_retired_verbs_are_gone_and_unreferenced() {
  local name="sync and render are gone, and no tracked file still calls them"
  local pkg; pkg="$(packed_root)"
  if [[ -z "$pkg" ]]; then bad "$name" "npm pack or extract failed"; return; fi

  local sb; sb="$(mk_sandbox)"
  local verb out code
  for verb in sync render; do
    out="$(cd "$ROOT" && run_packed "$pkg" "$sb" "$verb" 2>&1)"; code=$?
    if [[ "$code" -eq 0 ]]; then bad "$name" "$verb still succeeds"; return; fi
    if [[ "$out" != *"unknown command: $verb"* ]]; then bad "$name" "$verb did not report as unknown: $out"; return; fi
  done

  local leaked
  leaked="$(cd "$ROOT" && git grep -nE '(bin/)?orly (sync|render|validate)\b' -- . ':!docs/v1/done/*' ':!docs/v1/active/*' ':!evals/install/*' ':!SOUL_LOG.md' 2>/dev/null || true)"
  if [[ -n "$leaked" ]]; then bad "$name" "tracked references to a retired verb remain: $(printf '%s' "$leaked" | head -1)"; return; fi
  ok "$name"
}

# update re-materialises whatever the lock pinned, and a rule change should
# cost one command per repository — the property that replaces M01's
# zero-sync-commit guarantee. Prove it moves a real version forward.
install_update_repins_across_a_version_bump() {
  local name="update moves a repository from an older pinned version to the current one"
  local pkg repo; pkg="$(packed_root)"; repo="$(mk_repo)"
  if [[ -z "$pkg" ]]; then bad "$name" "npm pack or extract failed"; return; fi

  run_packed "$pkg" "$repo" init >/dev/null
  local before; before="$(python3 -c "import json;print(json.load(open('$repo/.oracle/orly.json'))['orly_version'])")"

  # Simulate a newer engine: bump the packed copy's own version and touch a
  # managed file, so update has a real, detectable change to propagate.
  python3 - "$pkg/package.json" <<'PY'
import json, sys
path = sys.argv[1]
data = json.load(open(path))
data["version"] = "0.4.1-test"
json.dump(data, open(path, "w"))
PY
  printf '\n<!-- eval: newer engine content -->\n' >> "$pkg/orly/packs/language/rust/rules.md"

  local out; out="$(run_packed "$pkg" "$repo" update)"
  local after; after="$(python3 -c "import json;print(json.load(open('$repo/.oracle/orly.json'))['orly_version'])")"

  if [[ "$before" == "$after" ]]; then bad "$name" "lock still pinned to $before after update"; return; fi
  if [[ "$after" != "0.4.1-test" ]]; then bad "$name" "lock repinned to '$after', not the newer engine"; return; fi
  if ! grep -q "eval: newer engine content" "$repo/dispatch/write_rust.md"; then
    bad "$name" "update did not propagate the changed file"; return
  fi
  if [[ "$out" != *"written"* ]]; then bad "$name" "update did not report what changed: $out"; return; fi
  ok "$name"
}

# The README's own claim: one command installs the harness anywhere. If the
# harness-install section carries more than one fenced command block, the
# "one command" claim in this milestone's own spec is false.
install_readme_harness_section_is_one_command() {
  local name="README's harness-install section is a single command block"
  local section
  section="$(awk '/^## Install the harness/{flag=1; next} /^## /{flag=0} flag' "$ROOT/README.md")"
  if [[ -z "$section" ]]; then bad "$name" "no '## Install the harness' section found"; return; fi

  local blocks
  blocks="$(printf '%s\n' "$section" | grep -c '^```bash$')"
  if [[ "$blocks" -ne 1 ]]; then bad "$name" "expected exactly 1 bash command block, found $blocks"; return; fi
  printf '%s\n' "$section" | grep -q 'bunx @indykish/orly init' || { bad "$name" "the block is not the init command"; return; }
  ok "$name"
}

# The architecture doc must record what it replaced, not just what exists now
# — a reader hitting the old M01 framing elsewhere needs the pointer.
install_architecture_doc_records_supersession() {
  local name="ORLY_ARCHITECTURE.md names the config, materialisation, and the superseded model"
  local doc; doc="$ROOT/docs/ORLY_ARCHITECTURE.md"
  local missing=""
  grep -q "orly.json" "$doc" || missing+="orly.json "
  grep -qi "materialis" "$doc" || missing+="materialise "
  grep -qE "M01|thin distribution" "$doc" || missing+="superseded-model-reference "
  if [[ -n "$missing" ]]; then bad "$name" "missing: $missing"; return; fi
  ok "$name"
}

# The release gate this repository lacked: make audit ran on the developer's
# machine only, behind a hooksPath that has to be set by hand. The workflow
# runs the exact same command on a fresh runner; prove the command it invokes
# genuinely fails on a real defect, and that the workflow names no path that
# only exists on this machine.
install_ci_workflow_gates_on_a_real_defect() {
  local name="the CI workflow's audit step fails on a seeded governance violation"
  local workflow="$ROOT/.github/workflows/harness.yml"
  [[ -f "$workflow" ]] || { bad "$name" "no .github/workflows/harness.yml"; return; }
  grep -q "make audit" "$workflow" || { bad "$name" "workflow does not run make audit"; return; }

  local leaked
  leaked="$(grep -E '/Users/|~/Projects' "$workflow" || true)"
  if [[ -n "$leaked" ]]; then bad "$name" "workflow names a developer-only path: $leaked"; return; fi

  # The workflow's own command, run against a tree with AGENTS.md staled out —
  # the same failure a stale render on any branch would trip in CI.
  local sb; sb="$(mk_sandbox)"
  cp -R "$ROOT"/. "$sb/repo" 2>/dev/null
  rm -rf "$sb/repo/.git"
  printf 'stale\n' >> "$sb/repo/AGENTS.md"
  local out code
  out="$(cd "$sb/repo" && make audit 2>&1)"; code=$?
  if [[ "$code" -eq 0 ]]; then bad "$name" "make audit did not catch the seeded staleness"; return; fi
  if [[ "$out" != *"stale"* && "$out" != *"REGRESSION"* ]]; then
    bad "$name" "failure did not name the staleness: ${out: -200}"; return
  fi
  ok "$name"
}

# Every language a pack can select for must install cleanly into its own fresh
# sandbox with zero dangling citations. Replaces the per-profile sweep: the
# selection axis is now the repository's own sources, so the eval varies those.
install_every_language_selection_installs_cleanly() {
  local name="every language selection installs with zero dangling references"
  local pkg; pkg="$(packed_root)"
  if [[ -z "$pkg" ]]; then bad "$name" "npm pack or extract failed"; return; fi

  local sample broken=""
  for sample in "src/lib.rs" "src/main.zig" "src/app.ts" "src/app.tsx" "src/app.js" "src/app.jsx" "src/app.py" "tool.sh" "docs/page.mdx" "schema/init.sql"; do
    local repo; repo="$(mk_repo)"
    local out code
    mkdir -p "$repo/$(dirname "$sample")"
    printf '// fixture\n' > "$repo/$sample"
    out="$(run_packed "$pkg" "$repo" init 2>&1)"; code=$?
    if [[ "$code" -ne 0 ]]; then broken+="$sample "; continue; fi

    local cited dangling=""
    while read -r cited; do
      [[ -z "$cited" ]] && continue
      [[ -e "$repo/$cited" ]] || dangling+="$cited "
    done < <(cited_dispatch_paths "$repo")
    [[ -n "$dangling" ]] && broken+="$sample(dangling:$dangling) "
  done
  if [[ -n "$broken" ]]; then bad "$name" "broken selections: $broken"; return; fi
  ok "$name"
}
