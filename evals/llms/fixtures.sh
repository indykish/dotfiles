# Fixture loading and validation for evals/llms/run.sh (python3 for robust
# JSON). Sourced, never executed: run.sh sets ROOT, FIXTURES and AGENTS_ALL,
# and defines have(), before sourcing this file.
# Split out of run.sh per dispatch/write_any.md §File & Function Length Gate.

fixtures_field() { # $1=field -> tab-joined id\tfield per line
  python3 -c '
import json,sys
for l in open(sys.argv[1]):
    l=l.strip()
    if not l: continue
    d=json.loads(l)
    print(d["id"]+"\t"+str(d[sys.argv[2]]))
' "$FIXTURES" "$1"
}

validate_fixtures() {
  python3 -c '
import json,sys,re
ids=set(); n=0; bad=0
for i,l in enumerate(open(sys.argv[1]),1):
    l=l.strip()
    if not l: continue
    try: d=json.loads(l)
    except Exception as e: print("BAD JSON line",i,e); bad+=1; continue
    for k in ("id","mode","expect","q","why"):
        if k not in d: print("line",i,"missing",k); bad+=1
    if d.get("expect") not in ("YES","NO"): print("line",i,"bad expect"); bad+=1
    if d.get("id") in ids: print("dup id",d.get("id")); bad+=1
    ctx = d.get("ctx")
    if ctx is not None:
        import os
        if not isinstance(ctx, list) or any(not isinstance(p, str) for p in ctx):
            print("line",i,"ctx must be a list of path strings"); bad+=1
        else:
            for p in ctx:
                if not os.path.isfile(os.path.join(sys.argv[2], p)):
                    print("line",i,"ctx path missing on disk:",p); bad+=1
    # Prompt-answerability: the prompt embeds AGENTS.md + gate bodies ONLY, not
    # audits/agents-md.md. A QUESTION that cites the invariance doc / a Scenario
    # number asks for an answer not in the prompt — the agent can only guess, so
    # it grades as "?" and silently drags the score. Enforce that every question
    # is answerable from the embedded ruleset. (The "why" field is provenance for
    # humans and is never sent to the agent, so it may cite Scenario N freely.)
    q = d.get("q","")
    if "AGENTS_INVARIANCE" in q or re.search(r"\bScenario\s+\d", q):
        print("line",i,"question cites AGENTS_INVARIANCE/Scenario (not in prompt):",d.get("id")); bad+=1
    ids.add(d.get("id")); n+=1
print("fixtures:",n)
sys.exit(1 if bad else 0)
' "$FIXTURES" "$ROOT"
}

fixtures_ctx() { # id \t (__FULL__ | __NONE__ | comma-joined ctx paths)
  python3 -c '
import json,sys
for l in open(sys.argv[1]):
    l=l.strip()
    if not l: continue
    d=json.loads(l)
    ctx=d.get("ctx")
    spec="__FULL__" if ctx is None else (",".join(ctx) if ctx else "__NONE__")
    print(d["id"]+"\t"+spec)
' "$FIXTURES"
}

list_available() {
  local a; for a in "${AGENTS_ALL[@]}"; do have "$a" && echo "$a"; done
}
