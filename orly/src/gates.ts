import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join, relative } from "node:path";

import { criteriaFor, CriterionContext, CriterionResult } from "./criteria";
import { OrlyError, RulesModel } from "./model";
import { defaultMergeBase } from "./surfaces";

export const GATE_ORDER = ["work", "verify", "pr"] as const;
export type GateName = (typeof GATE_ORDER)[number];

const PIPE_OUTPUT = "pipe";
const GIT = "git";
const DOCS_DIRECTORY = "docs";
const ACTIVE_DIRECTORY = "active";
// Accept every real layout: docs/v1/, docs/v2/, docs/v0.9.2/ — cache-kit
// versions its spec tree by release, not by prototype integer.
const PROTOTYPE_PATTERN = /^v\d+(\.\d+)*$/;
const MARKDOWN_EXTENSION = ".md";
const NEWLINE = "\n";
// Strict trailer shape: "Orly-Override: <criterion> (<reason>)". A trailer
// that does not parse is not an override — the gate stays red rather than
// guessing what a malformed waiver meant.
const OVERRIDE_TRAILER = /^Orly-Override:\s*([a-z.]+[a-z])\s*\((.+)\)\s*$/;
const OVERRIDE_PREFIX = "Orly-Override:";
const OVERRIDDEN_DETAIL = "overridden";

export type GateReport = {
  gate: GateName;
  results: CriterionResult[];
  ok: boolean;
};

export type Override = { criterion: string; reason: string };

// Run one gate: evaluate its criteria fresh from git + the working tree.
// A red criterion with a matching Orly-Override trailer on the branch is
// reported as overridden — satisfied, but never plain green.
export function runGate(model: RulesModel, root: string, gate: GateName, acceptDirty = false): GateReport {
  const context = gateContext(model, root, acceptDirty);
  const overrides = branchOverrides(root);
  const results = criteriaFor(gate, context).map((criterion) => {
    const result = criterion.evaluate(context);
    if (result.ok) return result;
    const override = overrides.find((entry) => entry.criterion === result.name);
    if (!override) return result;
    return { name: result.name, ok: true, detail: `${OVERRIDDEN_DETAIL} (${override.reason}) — ${result.detail}` };
  });
  return { gate, results, ok: results.every((result) => result.ok) };
}

// Run gates in order, stopping at the first red group: later gates are noise
// until the earlier boundary holds, and slow suites should not run on a
// branch that is not even clean.
export function runGates(model: RulesModel, root: string, acceptDirty = false): GateReport[] {
  const reports: GateReport[] = [];
  for (const gate of GATE_ORDER) {
    const report = runGate(model, root, gate, acceptDirty);
    reports.push(report);
    if (!report.ok) break;
  }
  return reports;
}

export function isGateName(value: string): value is GateName {
  return (GATE_ORDER as readonly string[]).includes(value);
}

// The override is an empty commit carrying a strict trailer: immutable once
// pushed, visible in the Pull Request, dead with the branch.
export function recordOverride(root: string, criterion: string, reason: string): string {
  const trimmed = reason.trim();
  if (!trimmed) throw new OrlyError("an override without a reason is not a record");
  const message = `override: ${criterion}\n\n${OVERRIDE_PREFIX} ${criterion} (${trimmed.replaceAll(")", "]")})`;
  const result = Bun.spawnSync([GIT, "commit", "--allow-empty", "-m", message], { cwd: root, stdout: PIPE_OUTPUT, stderr: PIPE_OUTPUT });
  if (result.exitCode !== 0) throw new OrlyError(`could not record the override commit: ${result.stderr.toString().trim()}`);
  return message;
}

// Overrides live in merge-base..HEAD commit bodies, so they are scoped to the
// branch and cannot leak past the merge.
export function branchOverrides(root: string): Override[] {
  const base = defaultMergeBase(root);
  if (!base) return [];
  const overrides: Override[] = [];
  for (const body of gitOutput(root, ["log", "--format=%B%x00", `${base}..HEAD`]).split("\0")) {
    for (const line of body.split(/\r?\n/)) {
      const match = line.trim().match(OVERRIDE_TRAILER);
      if (match?.[1] && match[2]) overrides.push({ criterion: match[1], reason: match[2].trim() });
    }
  }
  return overrides;
}

export function activeSpecPath(root: string): string | undefined {
  const specs = activeSpecPaths(root);
  if (specs.length === 0) return undefined;
  if (specs.length > 1) throw new OrlyError(`more than one active spec — one stream per worktree:${NEWLINE}${specs.join(NEWLINE)}`);
  return specs[0];
}

function gateContext(model: RulesModel, root: string, acceptDirty: boolean): CriterionContext {
  const specPath = activeSpecPath(root);
  const context: CriterionContext = { root, model, acceptDirty };
  if (specPath) {
    context.specPath = relative(root, specPath);
    context.specText = specTextSync(specPath);
  }
  return context;
}

function specTextSync(path: string): string {
  try {
    return readFileSync(path, "utf8");
  } catch {
    throw new OrlyError(`cannot read the active spec: ${path}`);
  }
}

function activeSpecPaths(root: string): string[] {
  const docs = join(root, DOCS_DIRECTORY);
  if (!existsSync(docs)) return [];
  const found: string[] = [];
  for (const prototype of readdirSync(docs).filter((name) => PROTOTYPE_PATTERN.test(name)).sort()) {
    const directory = join(docs, prototype, ACTIVE_DIRECTORY);
    if (!existsSync(directory)) continue;
    for (const file of readdirSync(directory).filter((name) => name.endsWith(MARKDOWN_EXTENSION)).sort()) found.push(join(directory, file));
  }
  return found;
}

function gitOutput(root: string, command: string[]): string {
  const result = Bun.spawnSync([GIT, ...command], { cwd: root, stdout: PIPE_OUTPUT, stderr: PIPE_OUTPUT });
  return result.exitCode === 0 ? result.stdout.toString().trim() : "";
}
