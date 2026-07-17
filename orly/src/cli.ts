#!/usr/bin/env bun
import { resolve } from "node:path";

import { isObject, OrlyError, RulesModel } from "./model";
import { Renderer } from "./render";
import {
  adoptRepository,
  doctorAgentHomes,
  doctorRepository,
  syncGlobal,
  syncRepository,
} from "./repository";
import { verifyAllProfiles, writeEvidence } from "./verify";

const REPOSITORY_SCOPE = "repository";
const ALL_SCOPE = "all";
const GLOBAL_SCOPE = "global";
const ALL_FLAG = "--all";
const PASS_RESULT = "pass";
const NOT_REQUIRED_RESULT = "not-required";

type Scope =
  | { kind: typeof REPOSITORY_SCOPE; name: string }
  | { kind: typeof ALL_SCOPE }
  | { kind: typeof GLOBAL_SCOPE };

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
  if (command === "adopt") {
    model.validate();
    const name = requiredRepository(rest);
    const files = await adoptRepository(model, name);
    console.log(`🟢 ${name}: adopted ${String(model.repository(name).profile)} (${files.length} files)`);
    return 0;
  }
  if (command === "sync") {
    model.validate();
    const scope = parseScope(rest);
    if (scope.kind === GLOBAL_SCOPE) {
      const links = await syncGlobal(model);
      console.log(`🟢 global: updated rules and ${links.length} agent-home links`);
      return 0;
    }
    return syncRepositories(model, repositoryNames(model, scope));
  }
  if (command === "doctor") {
    model.validate();
    const scope = parseScope(rest);
    if (scope.kind === GLOBAL_SCOPE) return doctorGlobal(model);
    return doctorRepositories(model, repositoryNames(model, scope));
  }
  if (command === "render") return render(model, rest);
  if (command === "verify") return verify(model, rest);
  throw new OrlyError(`unknown command: ${command}`);
}

async function syncRepositories(model: RulesModel, names: string[]): Promise<number> {
  let failed = false;
  for (const name of names) {
    try {
      const files = await syncRepository(model, name);
      console.log(`🟢 ${name}: synchronized ${files.length} files`);
    } catch (error) {
      failed = true;
      console.log(`🔴 ${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }
  return failed ? 1 : 0;
}

async function doctorRepositories(model: RulesModel, names: string[]): Promise<number> {
  let failed = false;
  for (const name of names) {
    const errors = await doctorRepository(model, name);
    if (errors.length > 0) {
      failed = true;
      console.log(`🔴 ${name}: ${errors.join("; ")}`);
    } else console.log(`🟢 ${name}: managed files match the ruleset lock`);
  }
  return failed ? 1 : 0;
}

async function doctorGlobal(model: RulesModel): Promise<number> {
  const errors = await doctorAgentHomes(model);
  if (errors.length > 0) {
    for (const error of errors) console.log(`🔴 ${error}`);
    return 1;
  }
  console.log("🟢 agent-home instructions use the generated global rules");
  return 0;
}

async function render(model: RulesModel, args: string[]): Promise<number> {
  model.validate();
  const profile = optionValue(args, "--profile");
  const output = optionValue(args, "--output");
  const projectRoot = optionalValue(args, "--project-root");
  const hashes = await new Renderer(model).render(profile, resolve(output), projectRoot ? resolve(projectRoot) : undefined);
  console.log(JSON.stringify(hashes, null, 2));
  return 0;
}

async function verify(model: RulesModel, args: string[]): Promise<number> {
  if (!args.includes(ALL_FLAG)) throw new OrlyError("verify requires --all");
  const checks = await verifyAllProfiles(model);
  for (const check of checks) console.log(`${check.result === PASS_RESULT ? "🟢" : "🔴"} ${check.name}${check.detail ? `: ${check.detail}` : ""}`);
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

function parseScope(args: string[]): Scope {
  if (args.length !== 1) throw new OrlyError("choose one repository, --all, or --global");
  if (args[0] === ALL_FLAG) return { kind: ALL_SCOPE };
  if (args[0] === "--global") return { kind: GLOBAL_SCOPE };
  return { kind: REPOSITORY_SCOPE, name: args[0] ?? "" };
}

function repositoryNames(model: RulesModel, scope: Scope): string[] {
  if (scope.kind === REPOSITORY_SCOPE) return [scope.name];
  if (scope.kind === ALL_SCOPE) return Object.keys(objectRepositories(model)).sort();
  throw new OrlyError("global scope does not select repositories");
}

function objectRepositories(model: RulesModel): Record<string, unknown> {
  const value = model.repositories.repositories;
  if (!isObject(value)) throw new OrlyError("repositories must be an object");
  return value;
}

function requiredRepository(args: string[]): string {
  if (args.length !== 1 || !args[0]) throw new OrlyError("adopt requires one registered repository name");
  return args[0];
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
  console.log(`orly — compose common rules with repository instructions

Usage:
  orly adopt <REPOSITORY>
  orly sync <REPOSITORY|--all|--global>
  orly doctor <REPOSITORY|--all|--global>`);
}
