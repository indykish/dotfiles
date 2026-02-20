# dotfiles

![Version](https://img.shields.io/badge/version-2.7.0-blue)

![This is fine](https://i.imgflip.com/2/1otk96.jpg)
*Me watching my agents edit my dotfiles at 3 AM.*

---

Personal dotfiles powered by the [Oracle Operating Model](AGENTS.md) — a single-role agent contract that makes AI coding agents deterministic and useful.

## Setup

```bash
git clone <this-repo> ~/Projects/dotfiles
cd ~/Projects/dotfiles
./scripts/run.sh
```

## What it does

`run.sh` deploys agent profiles and skills into your local agent config directories. Agents auto-load the profile at session start — zero typing needed.

The Oracle lifecycle runs on every non-trivial task:

```
PLAN → EXECUTE → VERIFY → DOCUMENT → COMMIT
```

## Update

```bash
cd ~/Projects/dotfiles && git pull && ./scripts/run.sh
```

## License

MIT
