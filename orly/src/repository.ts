import { lstatSync, readlinkSync, realpathSync, symlinkSync, unlinkSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";

import { localSelection } from "./config";
import { isBelow, OrlyError, RulesModel } from "./model";
import { Renderer } from "./render";

const AGENT_HOME_TARGETS = [
  ".claude/CLAUDE.md",
  ".codex/AGENTS.md",
  ".config/opencode/AGENTS.md",
  ".amp/AGENTS.md",
];
const AGENTS_FILENAME = "AGENTS.md";

// The one distribution motion left: render the root AGENTS.md and point every
// agent home at it. Rule changes reach every session through these links —
// there are no per-repository copies to synchronize.
export async function syncGlobal(model: RulesModel): Promise<string[]> {
  const local = await localSelection(model, model.root);
  const generated = await new Renderer(model).renderRoot(local.packs, local.commands);
  return linkAgentHomes(model, homedir(), generated);
}

export async function linkAgentHomes(
  model: RulesModel,
  home = homedir(),
  generated = join(model.root, AGENTS_FILENAME),
): Promise<string[]> {
  if (!pathExists(generated)) throw new OrlyError(`generated rules are missing: ${generated}`);
  const targets = agentHomeTargets(home);
  for (const target of targets) validateAgentHomeTarget(model, target);
  const linked: string[] = [];
  for (const target of targets) {
    if (pathExists(target) && lstatSync(target).isSymbolicLink()) {
      if (linkDestination(target) === realpathSync(generated)) {
        linked.push(target);
        continue;
      }
      unlinkSync(target);
    }
    symlinkSync(generated, target);
    linked.push(target);
  }
  return linked;
}

export async function doctorAgentHomes(
  model: RulesModel,
  home = homedir(),
  generated = join(model.root, AGENTS_FILENAME),
): Promise<string[]> {
  if (!pathExists(generated)) return [`generated rules are missing: ${generated}`];
  const local = await localSelection(model, model.root);
  const errors = await new Renderer(model).rootErrors(local.packs, local.commands);
  for (const target of agentHomeTargets(home)) {
    if (!pathExists(target) || !lstatSync(target).isSymbolicLink()) errors.push(`agent-home instructions are not linked: ${target}`);
    else if (linkDestination(target) !== realpathSync(generated)) errors.push(`agent-home instructions point elsewhere: ${target}`);
  }
  return errors;
}

export function agentHomeTargets(home: string): string[] {
  return AGENT_HOME_TARGETS.map((path) => join(home, path)).filter((path) => pathExists(dirname(path)));
}

function validateAgentHomeTarget(model: RulesModel, target: string): void {
  if (!pathExists(target)) return;
  if (!lstatSync(target).isSymbolicLink() || !isBelow(linkDestination(target), realpathSync(model.root))) throw new OrlyError(`refusing to replace agent-home file: ${target}`);
}

function linkDestination(path: string): string {
  const target = readlinkSync(path);
  const destination = resolve(dirname(path), target);
  return pathExists(destination) ? realpathSync(destination) : destination;
}

function pathExists(path: string): boolean {
  try {
    lstatSync(path);
    return true;
  } catch {
    return false;
  }
}
