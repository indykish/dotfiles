#!/usr/bin/env bun
import { existsSync } from "node:fs";
import { join, resolve } from "node:path";

import { localSelection } from "./config";
import { GateReport, isGateName, recordOverride, runGate, runGates } from "./gates";
import { install, InstallResult } from "./install";
import { lockDrift, LOCK_PATH, readLock, staleVersion } from "./lockfile";
import { isString, OrlyError, readJsonObject, RulesModel } from "./model";
import { Renderer } from "./render";
import { doctorAgentHomes, syncGlobal } from "./repository";
import { verifyRenders, writeEvidence } from "./verify";

const ALL_FLAG = "--all";
const PASS_RESULT = "pass";
const NOT_REQUIRED_RESULT = "not-required";
const ACCEPT_DIRTY_FLAG = "--accept-dirty";
const REASON_FLAG = "--reason";
const PIPE_OUTPUT = "pipe";
const PACKAGE_MANIFEST = "package.json";
const FORCE_FLAG = "--force";
const NO_HOOKS_FLAG = "--no-hooks";
const JSON_FLAG = "--json";
const JSON_INDENT = 2;
const PASS_GLYPH = "🟢";
const FAIL_GLYPH = "🔴";
const PR_GATE = "pr";
const ENGINE_MARKER = "evals/install/run.sh";
const VERIFY_COMMAND = "verify";

const { root, arguments: commandArguments } = parseRoot(Bun.argv.slice(2));

try {
  const model = await RulesModel.load(root);
  const exitCode = await run(model, commandArguments);
  process.exit(exitCode);
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`orly: ${message}`);
  process.exit(1);
}

async function run(model: RulesModel, args: string[]): Promise<number> {
  const [command, ...rest] = args;
  if (!command || command === "--help" || command === "-h") {
    printHelp();
    return command ? 0 : 1;
  }
  if (command === "--version" || command === "-v") return printVersion(model);
  if (command === "validate") {
    requireEngineCheckout(model, command);
    model.validate();
    console.log("orly: registry valid");
    return 0;
  }
  if (command === "sync") {
    requireEngineCheckout(model, command);
    model.validate();
    requireNoArguments(rest, "sync renders the root rules: orly sync");
    const links = await syncGlobal(model);
    console.log(`${PASS_GLYPH} rules rendered to AGENTS.md; ${links.length} agent-home links current`);
    return 0;
  }
  if (command === "doctor") {
    model.validate();
    requireNoArguments(rest, "doctor checks the root rules and home links: orly doctor");
    return doctorGlobal(model);
  }
  if (command === "init") return materialise(model, rest, true);
  if (command === "update") return materialise(model, rest, false);
  if (command === "render") return render(model, rest);
  if (command === VERIFY_COMMAND) return verify(model, rest);
  if (command === "gate") return gate(model, rest);
  if (command === "override") return override(rest);
  throw new OrlyError(`unknown command: ${command}`);
}

// Read-only: run every gate in order (stop at the first red group), or one
// named gate. Nothing is ever written.
function gate(model: RulesModel, args: string[]): number {
  const acceptDirty = args.includes(ACCEPT_DIRTY_FLAG);
  const named = args.find((argument) => !argument.startsWith("-"));
  if (named !== undefined && !isGateName(named)) throw new OrlyError(`unknown gate: ${named} (work, verify, pr)`);
  const reports = named ? [runGate(model, projectRoot(), named, acceptDirty)] : runGates(model, projectRoot(), acceptDirty);
  for (const report of reports) printGate(report);
  const allGreen = reports.every((report) => report.ok);
  if (allGreen && (named === undefined || named === PR_GATE)) console.log(`${PASS_GLYPH} PR boundary open — CHORE(close) is the next motion`);
  return allGreen ? 0 : 1;
}

function override(args: string[]): number {
  const criterion = args.find((argument) => !argument.startsWith("-")) ?? "";
  if (!criterion) throw new OrlyError("override requires one criterion name");
  const reason = optionalValue(args, REASON_FLAG)?.trim();
  if (!reason) throw new OrlyError(`${REASON_FLAG} is required and must not be empty — an override without a reason is not a record`);
  recordOverride(projectRoot(), criterion, reason);
  console.log(`🟡 recorded override of ${criterion} as an empty commit — it rides the branch into the PR`);
  return 0;
}

// The published manifest is the single version source — nothing in the sources
// carries a second copy that could disagree with what was installed.
async function printVersion(model: RulesModel): Promise<number> {
  console.log(await packageVersion(model));
  return 0;
}

async function packageVersion(model: RulesModel): Promise<string> {
  const manifest = await readJsonObject(join(model.root, PACKAGE_MANIFEST));
  if (!isString(manifest.version)) throw new OrlyError(`${PACKAGE_MANIFEST} carries no version string`);
  return manifest.version;
}

// Both verbs materialise the same way: the repository's own `.oracle/orly.json`
// names its packs and commands, so neither asks the caller who this repo is.
async function materialise(model: RulesModel, args: string[], isInit: boolean): Promise<number> {
  model.validate();
  const targetRoot = projectRoot();
  const lock = await readLock(targetRoot);
  if (!isInit && !lock) throw new OrlyError(`no ${LOCK_PATH} here — run \`orly init\` first`);
  const result = await install(model, {
    targetRoot,
    force: args.includes(FORCE_FLAG),
    installHooks: !args.includes(NO_HOOKS_FLAG),
    orlyVersion: await packageVersion(model),
  });
  if (args.includes(JSON_FLAG)) console.log(JSON.stringify(result, undefined, JSON_INDENT));
  else printInstall(result);
  return result.ok ? 0 : 1;
}

function printInstall(result: InstallResult): void {
  for (const error of result.errors) console.log(`${FAIL_GLYPH} ${error.path}: ${error.message} — ${error.suggestion}`);
  if (!result.ok) return;
  console.log(`${PASS_GLYPH} ${result.written.length} written, ${result.skipped.length} already current (${result.packs.length} packs)`);
}

function printGate(report: GateReport): void {
  console.log(`🔆 gate ${report.gate}`);
  for (const result of report.results) console.log(`   ${result.ok ? PASS_GLYPH : FAIL_GLYPH} ${result.name}: ${result.detail}`);
}

function projectRoot(): string {
  const result = Bun.spawnSync(["git", "rev-parse", "--show-toplevel"], { stdout: PIPE_OUTPUT, stderr: PIPE_OUTPUT });
  if (result.exitCode !== 0) throw new OrlyError(`not inside a Git repository: ${process.cwd()} — run \`git init\` first`);
  return result.stdout.toString().trim();
}

async function doctorGlobal(model: RulesModel): Promise<number> {
  // The agent-home links are this machine's rule carrier and only exist in an
  // orly checkout. From a published payload doctor reports on the repository
  // the caller is standing in — the only thing that install owns there.
  const engine = existsSync(join(model.root, ENGINE_MARKER));
  const errors = engine ? await doctorAgentHomes(model) : [];
  errors.push(...(await doctorInstall(model)));
  if (errors.length > 0) {
    for (const error of errors) console.log(`${FAIL_GLYPH} ${error}`);
    return 1;
  }
  if (engine) console.log(`${PASS_GLYPH} root AGENTS.md is current and every agent home links to it`);
  const lock = await readLock(projectRoot());
  if (lock) console.log(`${PASS_GLYPH} this repository's installed ruleset matches ${LOCK_PATH}`);
  else if (!engine) console.log(`${FAIL_GLYPH} no ${LOCK_PATH} here — run \`orly init\` first`);
  return lock || engine ? 0 : 1;
}

// A repository with no lock was never installed into — silence, not a finding.
// One that has a lock must still match it, or the rules it claims to enforce
// are not the rules on disk.
async function doctorInstall(model: RulesModel): Promise<string[]> {
  const targetRoot = projectRoot();
  const lock = await readLock(targetRoot);
  if (!lock) return [];
  const stale = staleVersion(lock, await packageVersion(model));
  return [...(await lockDrift(targetRoot, lock)), ...(stale ? [stale] : [])];
}

async function render(model: RulesModel, args: string[]): Promise<number> {
  model.validate();
  const projectRootPath = optionalValue(args, "--project-root");
  const target = projectRootPath ? resolve(projectRootPath) : model.root;
  const local = await localSelection(model, target);
  const text = await new Renderer(model).renderText(local.packs, local.commands, projectRootPath ? target : undefined);
  console.log(text);
  return 0;
}

async function verify(model: RulesModel, args: string[]): Promise<number> {
  requireEngineCheckout(model, VERIFY_COMMAND);
  if (!args.includes(ALL_FLAG)) throw new OrlyError("verify requires --all");
  const checks = await verifyRenders(model);
  for (const check of checks) console.log(`${check.result === PASS_RESULT ? PASS_GLYPH : FAIL_GLYPH} ${check.name}${check.detail ? `: ${check.detail}` : ""}`);
  if (args.includes("--write-evidence")) {
    const result = optionalValue(args, "--llm-result") ?? NOT_REQUIRED_RESULT;
    if (result !== PASS_RESULT && result !== NOT_REQUIRED_RESULT) throw new OrlyError("--llm-result must be pass or not-required");
    console.log(`evidence: ${await writeEvidence(model, "dotfiles", checks, result)}`);
  }
  return checks.every((check) => check.result === PASS_RESULT) ? 0 : 1;
}

// Ruleset-authoring verbs operate on the engine's own sources and, in sync's
// case, repoint this machine's agent homes at the render. From a published
// payload that render lives in a package cache, so the links would resolve into
// a directory the package manager may delete — the rules would vanish mid-
// session. The marker is a file the payload allowlist deliberately excludes and
// every checkout carries; `.git` would be wrong, since a CI job or an exported
// tree is still the engine and a package cache never is.
function requireEngineCheckout(model: RulesModel, command: string): void {
  if (existsSync(join(model.root, ENGINE_MARKER))) return;
  throw new OrlyError(`orly ${command} edits the ruleset itself and only runs in an orly checkout — from an installed package use \`orly init\`, \`orly update\`, \`orly doctor\`, or \`orly gate\``);
}

function parseRoot(args: string[]): { root: string; arguments: string[] } {
  const index = args.indexOf("--root");
  if (index < 0) return { root: resolve(import.meta.dir, "../.."), arguments: args };
  const value = args[index + 1];
  if (!value) throw new OrlyError("--root requires a path");
  return { root: resolve(value), arguments: args.filter((_, position) => position !== index && position !== index + 1) };
}

function requireNoArguments(args: string[], usage: string): void {
  if (args.length > 0) throw new OrlyError(usage);
}

function optionValue(args: string[], name: string): string {
  const value = optionalValue(args, name);
  if (!value) throw new OrlyError(`${name} is required`);
  return value;
}

function optionalValue(args: string[], name: string): string | undefined {
  const index = args.indexOf(name);
  return index < 0 ? undefined : args[index + 1];
}

function printHelp(): void {
  console.log(`orly — prove the boundary; carry the rules

Gates (read-only; no PR without every criterion green or a recorded override):
  orly gate [--accept-dirty]        run work → verify → pr; stop at first red
  orly gate <work|verify|pr>        run one gate
  orly override <CRITERION> --reason <REASON>
                                    empty commit with an Orly-Override trailer

Install (the repository is the unit — no checkout of this package required):
  orly init [--force] [--no-hooks] [--json]
                                    materialise rules, gates, hooks, the lock,
                                    and a seeded .oracle/orly.json
  orly update [--force] [--json]    re-materialise at the installed engine version

  orly doctor                       installed-ruleset drift and staleness
  orly --version                    the installed package version

Ruleset authoring (an orly checkout only — refused from an installed package):
  orly sync                         render the root rules + relink agent homes
  orly render [--project-root <DIR>]
                                    print a repository's render (stdout)
  orly verify --all                 render determinism + root currency
  orly validate                     registry shape`);
}
