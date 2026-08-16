import { existsSync, mkdirSync, mkdtempSync, realpathSync, renameSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, extname, join, relative, resolve } from "node:path";

import { UNSCOPED_ENVIRONMENT } from "./git_env";
import { applyMode, buildLock, hashContent, LockEntry, modeLabel, readLock, writeLock } from "./lockfile";
import { isString, JsonObject, objectArray, objectValue, OrlyError, RulesModel, stringArray } from "./model";
import { referenceClosureErrors, renderProfileText } from "./references";
import { Renderer } from "./render";

const AGENTS_FILENAME = "AGENTS.md";
const HOOKS_DIRECTORY = ".githooks";
const GLOBAL_PROFILE = "global";
const KERNEL_PROFILE = "kernel";
const REGISTRY_PACKS_LABEL = "registry packs";
const STAGE_PREFIX = "orly-install-";
const MARKDOWN_EXTENSION = ".md";
const MODE_EXECUTABLE = "0755";
const MODE_REGULAR = "0644";
const GIT_COMMAND = "git";
const GIT_REPO_FLAG = "-C";
const PIPE_OUTPUT = "pipe";
const HOOK_GATES = [["pre-commit", "work"], ["pre-push", "verify"]] as const;

export type InstallError = { path: string; message: string; suggestion: string };

export type InstallResult = {
  ok: boolean;
  profile: string;
  packs: string[];
  written: string[];
  skipped: string[];
  errors: InstallError[];
};

export type InstallOptions = {
  targetRoot: string;
  profile?: string | undefined;
  force: boolean;
  installHooks: boolean;
  orlyVersion: string;
};

type PlannedFile = { target: string; content: Uint8Array; mode: string };

// Materialise a profile into a repository: its rules, the gates that enforce
// them, the hooks that run the gates, and a lock recording exactly what landed.
// Everything is staged in a temporary directory first, so a run that refuses —
// or dies — leaves the target untouched rather than half-installed.
export async function install(model: RulesModel, options: InstallOptions): Promise<InstallResult> {
  const targetRoot = resolve(options.targetRoot);
  requireWorkTree(targetRoot);
  const profileName = options.profile ?? inferProfile(model, targetRoot);
  const profile = model.profile(profileName);
  const packs = selectedPackNames(model, profileName, profile);

  const planned = await planFiles(model, profileName, profile, packs);
  const lock = await readLock(targetRoot);
  const managed = new Set(Object.keys(lock?.files ?? {}));
  const refusals: InstallError[] = [];
  const written: string[] = [];
  const skipped: string[] = [];

  for (const file of planned) {
    const path = join(targetRoot, file.target);
    if (!existsSync(path)) { written.push(file.target); continue; }
    const actual = hashContent(await Bun.file(path).bytes());
    if (actual === hashContent(file.content) && modeLabel(path) === file.mode) { skipped.push(file.target); continue; }
    const recorded = lock?.files[file.target];
    if (options.force || (recorded && recorded.sha256 === actual)) { written.push(file.target); continue; }
    refusals.push(refusal(file.target, managed.has(file.target)));
  }
  if (refusals.length > 0) return { ok: false, profile: profileName, packs, written: [], skipped, errors: refusals };

  const closure = await stageAndCommit(model, targetRoot, planned, written);
  if (closure.length > 0) return { ok: false, profile: profileName, packs, written: [], skipped, errors: closure };

  const hooks = options.installHooks ? await installHooks(targetRoot) : { written: [], all: [] };
  written.push(...hooks.written);
  skipped.push(...hooks.all.filter((path) => !hooks.written.includes(path)));
  const entries = await lockEntries(targetRoot, planned, hooks.all);
  await writeLock(targetRoot, buildLock(options.orlyVersion, profileName, packs, entries));
  return { ok: true, profile: profileName, packs, written: written.sort(), skipped: skipped.sort(), errors: [] };
}

function refusal(target: string, wasManaged: boolean): InstallError {
  return wasManaged
    ? { path: target, message: "managed file was edited in place since it was installed", suggestion: "revert the edit, or re-run with --force to overwrite it" }
    : { path: target, message: "a file already exists here and orly did not write it", suggestion: "move it aside, or re-run with --force to replace it" };
}

// The payload is written to a scratch directory and only moved into the target
// once every file exists and every reference it names resolves. Reference
// closure runs against the staged tree, so a pack whose façade cites a document
// no selected pack provides is caught before anything lands.
async function stageAndCommit(model: RulesModel, targetRoot: string, planned: PlannedFile[], written: string[]): Promise<InstallError[]> {
  const stage = mkdtempSync(join(tmpdir(), STAGE_PREFIX));
  try {
    for (const file of planned) {
      const path = join(stage, file.target);
      mkdirSync(dirname(path), { recursive: true });
      await Bun.write(path, file.content);
      applyMode(path, file.mode);
    }
    const markdown = planned.filter((file) => extname(file.target) === MARKDOWN_EXTENSION).map((file) => join(stage, file.target));
    const missing = await referenceClosureErrors(stage, markdown);
    if (missing.length > 0) return missing.map((message) => ({ path: AGENTS_FILENAME, message, suggestion: "select the pack that provides the cited file, or amend the citation" }));

    const targets = new Set(written);
    for (const file of planned.filter((candidate) => targets.has(candidate.target))) {
      const destination = join(targetRoot, file.target);
      mkdirSync(dirname(destination), { recursive: true });
      renameSync(join(stage, file.target), destination);
      applyMode(destination, file.mode);
    }
    return [];
  } finally {
    rmSync(stage, { recursive: true, force: true });
  }
}

// Hooks are generated, never copied: this repository's own hooks run `make
// audit` and `bin/orly verify`, neither of which exists in a consumer. What a
// consumer needs is the gate engine, reached through the binary that installed
// it — with a PATH fallback so a relocated checkout still resolves.
async function installHooks(targetRoot: string): Promise<{ written: string[]; all: string[] }> {
  const directory = join(targetRoot, HOOKS_DIRECTORY);
  mkdirSync(directory, { recursive: true });
  const written: string[] = [];
  const all: string[] = [];
  for (const [name, gate] of HOOK_GATES) {
    const path = join(directory, name);
    const script = hookScript(gate);
    all.push(`${HOOKS_DIRECTORY}/${name}`);
    if (existsSync(path) && (await Bun.file(path).text()) === script && modeLabel(path) === MODE_EXECUTABLE) continue;
    await Bun.write(path, script);
    applyMode(path, MODE_EXECUTABLE);
    written.push(`${HOOKS_DIRECTORY}/${name}`);
  }
  runGit(targetRoot, ["config", "core.hooksPath", HOOKS_DIRECTORY]);
  return { written, all };
}

function hookScript(gate: string): string {
  return [
    "#!/usr/bin/env bash",
    "# Generated by orly. Re-run `orly init` to refresh.",
    "set -euo pipefail",
    "",
    "# git exports these to every hook; inherited by a spawned git they pin it to",
    "# the hook's repository instead of the one being judged.",
    "unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_COMMON_DIR GIT_PREFIX \\",
    "      GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES",
    "",
    'if ! command -v orly >/dev/null 2>&1; then',
    '    printf "orly: not on PATH — install it with `bun add -g @indykish/orly`, or delete this hook\\n" >&2',
    "    exit 1",
    "fi",
    "",
    `exec orly gate ${gate}`,
    "",
  ].join("\n");
}

async function lockEntries(targetRoot: string, planned: PlannedFile[], hooks: string[]): Promise<Record<string, LockEntry>> {
  const entries: Record<string, LockEntry> = {};
  for (const file of planned) entries[file.target] = { sha256: hashContent(file.content), mode: file.mode };
  for (const target of hooks) {
    const path = join(targetRoot, target);
    entries[target] = { sha256: hashContent(await Bun.file(path).bytes()), mode: modeLabel(path) };
  }
  return entries;
}

// One entry per target, so two packs naming the same file collapse instead of
// racing. Two packs naming DIFFERENT sources for one target is a registry bug
// and stops the install rather than letting pack order decide the winner.
async function planFiles(model: RulesModel, profileName: string, profile: JsonObject, packs: string[]): Promise<PlannedFile[]> {
  const registryPacks = objectValue(model.registry.packs, REGISTRY_PACKS_LABEL);
  const known = new Set(Object.keys(registryPacks));
  const planned = new Map<string, PlannedFile>();
  const sources = new Map<string, string>();
  for (const name of packs) {
    const pack = objectValue(registryPacks[name], `pack ${name}`);
    for (const entry of objectArray(pack.managed_files, `pack ${name} managed_files`)) {
      if (!isString(entry.source) || !isString(entry.target)) throw new OrlyError(`pack ${name} managed file must carry string source and target`);
      const claimed = sources.get(entry.target);
      if (claimed && claimed !== entry.source) throw new OrlyError(`packs disagree on ${entry.target}: ${claimed} and ${entry.source}`);
      sources.set(entry.target, entry.source);
      const path = join(model.root, entry.source);
      planned.set(entry.target, { target: entry.target, content: await managedContent(path, entry.target, entry.source, packs, known), mode: modeLabel(path) });
    }
  }
  const rendered = await new Renderer(model).renderText(profileName);
  planned.set(AGENTS_FILENAME, { target: AGENTS_FILENAME, content: new TextEncoder().encode(rendered), mode: MODE_REGULAR });
  return [...planned.values()].sort((left, right) => left.target.localeCompare(right.target));
}

// Managed markdown is pack-filtered on the way in, exactly as a rendered core
// document is. Copying it raw is how a Rust crate ends up holding a rule that
// points at a Zig façade it will never receive.
async function managedContent(path: string, target: string, source: string, packs: string[], known: Set<string>): Promise<Uint8Array> {
  const bytes = await Bun.file(path).bytes();
  if (extname(target) !== MARKDOWN_EXTENSION) return bytes;
  const filtered = renderProfileText(new TextDecoder().decode(bytes), new Set(packs), known, source);
  return new TextEncoder().encode(`${filtered}\n`);
}

function selectedPackNames(model: RulesModel, profileName: string, profile: JsonObject): string[] {
  const known = Object.keys(objectValue(model.registry.packs, REGISTRY_PACKS_LABEL));
  if (profileName === GLOBAL_PROFILE) return known.sort();
  return [...stringArray(profile.packs, `profile ${profileName} packs`)].sort();
}

// A repository already registered here keeps its profile. Anything else gets
// the kernel default — every language and domain pack, nothing named or
// personal — so a fresh clone never needs to know a profile name exists.
function inferProfile(model: RulesModel, targetRoot: string): string {
  const repositories = objectValue(model.repositories.repositories, "repositories");
  for (const [name, value] of Object.entries(repositories)) {
    const path = objectValue(value, `repository ${name}`).path;
    if (isString(path) && resolve(expandHome(path)) === targetRoot && isString(objectValue(value, name).profile)) {
      return String(objectValue(value, name).profile);
    }
  }
  if (KERNEL_PROFILE in model.profiles) return KERNEL_PROFILE;
  throw new OrlyError(`no profile registered for ${targetRoot} — pass --profile <NAME> (available: ${Object.keys(model.profiles).sort().join(", ")})`);
}

function expandHome(path: string): string {
  return path.startsWith("~/") ? join(process.env.HOME ?? "", path.slice(2)) : path;
}

// git canonicalises symlinks in --show-toplevel; targetRoot, as handed in by
// a caller, usually has not been (macOS puts $TMPDIR and often the caller's
// own working directory behind one). Comparing without resolving both sides
// made every install from a symlinked path — routine on macOS — refuse with
// "not the repository root" against its own root.
function requireWorkTree(targetRoot: string): void {
  if (!existsSync(targetRoot)) throw new OrlyError(`target directory does not exist: ${targetRoot}`);
  const result = Bun.spawnSync([GIT_COMMAND, GIT_REPO_FLAG, targetRoot, "rev-parse", "--show-toplevel"], { stdout: PIPE_OUTPUT, stderr: PIPE_OUTPUT, env: UNSCOPED_ENVIRONMENT });
  if (result.exitCode !== 0) throw new OrlyError(`not a git repository: ${targetRoot} — run \`git init\` first`);
  const top = resolve(result.stdout.toString().trim());
  const resolvedTarget = realpathSync(targetRoot);
  if (top !== resolvedTarget) throw new OrlyError(`install at the repository root, not a subdirectory: ${relative(top, resolvedTarget)}`);
}

function runGit(targetRoot: string, args: string[]): void {
  const result = Bun.spawnSync([GIT_COMMAND, GIT_REPO_FLAG, targetRoot, ...args], { stdout: PIPE_OUTPUT, stderr: PIPE_OUTPUT, env: UNSCOPED_ENVIRONMENT });
  if (result.exitCode !== 0) throw new OrlyError(`git ${args.join(" ")} failed: ${result.stderr.toString().trim()}`);
}
