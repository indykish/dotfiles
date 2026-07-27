#!/usr/bin/env bun
import { resolve } from "node:path";

import { GateReport, isGateName, recordOverride, runGate, runGates } from "./gates";
import { OrlyError, RulesModel } from "./model";
import { Renderer } from "./render";
import { doctorAgentHomes, syncGlobal } from "./repository";
import { verifyAllProfiles, writeEvidence } from "./verify";

const ALL_FLAG = "--all";
const GLOBAL_FLAG = "--global";
const PASS_RESULT = "pass";
const NOT_REQUIRED_RESULT = "not-required";
const ACCEPT_DIRTY_FLAG = "--accept-dirty";
const REASON_FLAG = "--reason";
const PIPE_OUTPUT = "pipe";
const PASS_GLYPH = "🟢";
const FAIL_GLYPH = "🔴";
const PR_GATE = "pr";

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
  if (command === "validate") {
    model.validate();
    console.log("orly: registry and profiles valid");
    return 0;
  }
  if (command === "sync") {
    model.validate();
    requireGlobalOnly(rest, "sync renders the root rules: orly sync [--global]");
    const links = await syncGlobal(model);
    console.log(`${PASS_GLYPH} rules rendered to AGENTS.md; ${links.length} agent-home links current`);
    return 0;
  }
  if (command === "doctor") {
    model.validate();
    requireGlobalOnly(rest, "doctor checks the root rules and home links: orly doctor [--global]");
    return doctorGlobal(model);
  }
  if (command === "render") return render(model, rest);
  if (command === "verify") return verify(model, rest);
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

function printGate(report: GateReport): void {
  console.log(`🔆 gate ${report.gate}`);
  for (const result of report.results) console.log(`   ${result.ok ? PASS_GLYPH : FAIL_GLYPH} ${result.name}: ${result.detail}`);
}

function projectRoot(): string {
  const result = Bun.spawnSync(["git", "rev-parse", "--show-toplevel"], { stdout: PIPE_OUTPUT, stderr: PIPE_OUTPUT });
  if (result.exitCode !== 0) throw new OrlyError("not inside a Git repository");
  return result.stdout.toString().trim();
}

async function doctorGlobal(model: RulesModel): Promise<number> {
  const errors = await doctorAgentHomes(model);
  if (errors.length > 0) {
    for (const error of errors) console.log(`${FAIL_GLYPH} ${error}`);
    return 1;
  }
  console.log(`${PASS_GLYPH} root AGENTS.md is current and every agent home links to it`);
  return 0;
}

async function render(model: RulesModel, args: string[]): Promise<number> {
  model.validate();
  const profile = optionValue(args, "--profile");
  const projectRootPath = optionalValue(args, "--project-root");
  const text = await new Renderer(model).renderText(profile, projectRootPath ? resolve(projectRootPath) : undefined);
  console.log(text);
  return 0;
}

async function verify(model: RulesModel, args: string[]): Promise<number> {
  if (!args.includes(ALL_FLAG)) throw new OrlyError("verify requires --all");
  const checks = await verifyAllProfiles(model);
  for (const check of checks) console.log(`${check.result === PASS_RESULT ? PASS_GLYPH : FAIL_GLYPH} ${check.name}${check.detail ? `: ${check.detail}` : ""}`);
  if (args.includes("--write-evidence")) {
    const result = optionalValue(args, "--llm-result") ?? NOT_REQUIRED_RESULT;
    if (result !== PASS_RESULT && result !== NOT_REQUIRED_RESULT) throw new OrlyError("--llm-result must be pass or not-required");
    console.log(`evidence: ${await writeEvidence(model, "dotfiles", checks, result)}`);
  }
  return checks.every((check) => check.result === PASS_RESULT) ? 0 : 1;
}

function parseRoot(args: string[]): { root: string; arguments: string[] } {
  const index = args.indexOf("--root");
  if (index < 0) return { root: resolve(import.meta.dir, "../.."), arguments: args };
  const value = args[index + 1];
  if (!value) throw new OrlyError("--root requires a path");
  return { root: resolve(value), arguments: args.filter((_, position) => position !== index && position !== index + 1) };
}

function requireGlobalOnly(args: string[], usage: string): void {
  if (args.length > 0 && (args.length !== 1 || args[0] !== GLOBAL_FLAG)) throw new OrlyError(usage);
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

Rules (one render target — the root AGENTS.md every agent home links to):
  orly sync [--global]              render the root rules + relink agent homes
  orly doctor [--global]            root currency + home links
  orly render --profile <NAME>      print a profile's render (stdout)
  orly verify --all                 per-profile determinism + root currency
  orly validate                     registry and profile shape`);
}
