# AI Jumpstart

**Learning resources for AI-native engineering workflows.**

Jumpstart your journey with AI coding agents through presentations, videos, and guides curated by the E2E Networks engineering team.

---

## 📺 Presentations & Videos

### Product Management with AI Tools

🎬 **[PM with AI Tools](https://www.youtube.com/watch?v=YKYQ-z6A9Fs)**  
Learn how to leverage AI tools for effective product management.

---

### AI Bootcamp

Internal training series on AI-native development workflows.

| Week | Date | Topic | Link |
|------|------|-------|------|
| Week 1 | Jan 27 | Foundations | [View Presentation](https://show.zoho.com/show/open/n6wbv3d4f13ed65db4a6bb0044c96a5b4c9f4/slide/8fcf55d4-8aac-4833-a342-9d60c90d2b6d) |
| Week 2 | Feb 3 | Deep Dive | [View Presentation](https://show.zoho.com/show/open/a86lo769a284c266c47408785350379cb55ad/slide/c8dc9873-7cf3-4480-a77e-cc91499204c3) |
| Week 3 | Feb 9 | Hands-on Demo | _Recording coming soon_ |
| Week 4 | Feb 16 | Hands-on Demo | _Recording coming soon_ |

---

### MyAccount 2 / SRE Series

Engineering operations and roadmap alignment for AI workflows.

| Date | Topic | Link |
|------|-------|------|
| Feb 9 | Engg Ops | [View Presentation](https://show.zoho.com/show/open/n6wbv3d4f13ed65db4a6bb0044c96a5b4c9f4/slide/8fcf55d4-8aac-4833-a342-9d60c90d2b6d) |
| Feb 9 | Roadmap | [View Presentation](https://show.zoho.com/show/open/n6wbvd684f4ab596a4094bbd3f76b6f0b8887/slide/533168e6-59fd-4817-a513-28970673eab1) |

---

## Getting Started

```bash
git clone git@awakeninggit.e2enetworks.net:engineering/ai-jumpstart.git ~/Projects/ai-jumpstart
cd ~/Projects/ai-jumpstart
./scripts/run.sh
```

This clones the repo, then deploys the Oracle Operating Model profile and all skills into every supported agent. After running, open any agent (Claude Code, Codex, OpenCode, AmpCode, KiloCode) and the profile is active immediately.

To update after pulling new changes:

```bash
cd ~/Projects/ai-jumpstart && git pull && ./scripts/run.sh
```

---

## Secrets (Do Not Commit)

This repo intentionally stores only **dummy placeholders** for API keys/tokens.

- Source of truth: Proton Pass vault `AGENTS_BUFFET`

Environment variables used by agent tooling (store values in Proton Pass, then export locally):

- `MOONSHOT_API_KEY` (Kimi 2.5)
- `OLLAMA_CLOUD_API_KEY` (only if using Ollama cloud)
- `MINIMAX_API_KEY`
- `ZAI_API_KEY`

---

## Skills & Agent Configuration

Production-ready skills and the Oracle Operating Model for AI coding agents.

### What `run.sh` Deploys

This deploys `CLAUDE.md` / `AGENTS.md` and all skills into each agent's home directory:

| Agent | Profile | Skills Dir |
|-------|---------|------------|
| Claude Code | `~/.claude/CLAUDE.md` | `~/.claude/commands/` |
| Codex | `~/.codex/AGENTS.md` | `~/.codex/skills/` |
| OpenCode | `~/.opencode/AGENTS.md` | `~/.opencode/skills/` |
| AmpCode | `~/.ampcode/AGENTS.md` | `~/.ampcode/skills/` |
| KiloCode | `~/.kilocode/AGENTS.md` | `~/.kilocode/skills/` |

Options:
- `--clean` removes ai-jumpstart-managed files before syncing.

### What Loads Automatically

Every agent auto-loads its profile (`AGENTS.md` or `CLAUDE.md`) at session start. The **Oracle Operating Model** (lifecycle, safety rules, routing, docs discipline, communication contract) is always active -- zero typing required.

The deterministic lifecycle `PLAN -> EXECUTE -> VERIFY -> DOCUMENT -> COMMIT` is enforced on every non-trivial task. Agents surface assumptions before coding and follow the full state machine.

### Skills (Invoke Explicitly)

Skills are workflows you trigger on demand. In Claude Code, use slash commands (`/skill-name`). In other agents, reference the skill by name in your prompt.

| Skill | Purpose |
|-------|---------|
| `/preflight-tooling` | Detect and install missing CLI tools (run once per machine) |
| `/review-pr` | Review a PR/MR diff (auto-detects language and forge) |
| `/create-scaffold <stack>` | Scaffold a project (`python`, `rust`, `go`, `typescript`, `javascript-cli`, `tauri`) |
| `/create-cli` | Design CLI parameters and UX |
| `/e2e-qa-playwright` | Run or setup Playwright E2E tests |
| `/oracle` | Get a second-model review via the Oracle CLI |
| `/update-docs-and-commit` | Update docs then prepare a commit |
| `/frontend-design` | Frontend design guidance |
| `/zoho-sprint` | Zoho Sprint setup |
| `/zoho-desk` | Zoho Desk setup |

Full catalog: [`skills/README.md`](skills/README.md).

### Working Efficiently

**Short prompts work.** The auto-loaded profile handles context. Just state the task:

```
> "scaffold a python api"        # agent follows lifecycle automatically
> "review this backend"           # triggers review workflow
> /oracle                         # second-model cross-validation
> /update-docs-and-commit         # docs + commit in one shot
> /preflight-tooling              # once per machine/session
```

The communication contract means agents surface assumptions **before** coding, so fewer round-trips are needed. Correct the assumptions once and the agent proceeds.

---

## 📚 Team Resources

### Hiring Talent 2026
[Hiring Guide](https://gist.github.com/indykish/cc197cc801ad722de2b83580de1ab502)  
Guidelines and resources for hiring engineering talent in 2026.

### Zoho Documentation
[Zoho WorkDrive Folder](https://workdrive.zoho.com/b849ye95c8e369c6946818ef874fc63107dbe/teams/b849ye95c8e369c6946818ef874fc63107dbe/ws/cyy3w07251e1830134377984769267366ad54/folders/files)  
Shared documentation, templates, and guides.

### Apply The Algorithm constantly. 

(1) Question every requirement. 

(2) Delete any part of the process you can. 

(3) Simplify and optimize. 

(4) Accelerate cycle time. 

(5) Automate.


---

## 🔧 Internal Repositories

### Engineering Decision Records
**[engineering/adr](https://awakeninggit.e2enetworks.net/engineering/adr)**  
Architecture decision records and technical trade-off documentation.

### SRE Runbooks
**[infra/sre](https://awakeninggit.e2enetworks.net/infra/)**  
Site reliability engineering runbooks and operational procedures.

### Diagrams
**[infra/diagrams](https://awakeninggit.e2enetworks.net/engineering/diagrams.git)**  
Architecture diagrams (Mermaid). *Moving to relevant repos.*

---

## 📝 License

Internal resource for E2E Networks engineering team.

---

## 🆘 Support

**Issues**: [awakeninggit.e2enetworks.net/engineering/ai-jumpstart](https://awakeninggit.e2enetworks.net/engineering/ai-jumpstart/-/issues)

**Maintainers**: Engineering team (see [CODEOWNERS](CODEOWNERS))
