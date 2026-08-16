import { existsSync, mkdirSync, mkdtempSync, readdirSync, realpathSync, renameSync, rmSync } from "node:fs";
import { dirname, extname, join, relative, resolve } from "node:path";

import { UNSCOPED_ENVIRONMENT } from "./git_env";
import { CONFIG_PATH, readConfig, seedConfig, selectPacks, writeConfig } from "./config";
import { applyMode, buildLock, hashContent, LOCK_PATH, LockEntry, modeLabel, readLock, writeLock } from "./lockfile";
import { assertWritableInside, isString, JsonObject, objectArray, objectValue, OrlyError, RulesModel, stringArray } from "./model";
import { referenceClosureErrors, renderProfileText } from "./references";
import { Renderer } from "./render";

const AGENTS_FILENAME = "AGENTS.md";
const HOOKS_DIRECTORY = ".githooks";
const REGISTRY_PACKS_LABEL = "registry packs";
const STAGE_PREFIX = "orly-install-";
const MARKDOWN_EXTENSION = ".md";
const MODE_EXECUTABLE = "0755";
const MODE_REGULAR = "0644";
const GIT_COMMAND = "git";
const GIT_REPO_FLAG = "-C";
const PIPE_OUTPUT = "pipe";
const HOOK_GATES = [["pre-commit", "work"], ["pre-push", "verify"]] as const;
const GIT_CONFIG_SUBCOMMAND = "config";
const HOOKS_PATH_KEY = "core.hooksPath";
const MANAGED_FILE_KIND = "managed file";
const HOOK_KIND = "hook";

export type InstallError = { path: string; message: string; suggestion: string };

export type InstallResult = {
  ok: boolean;
  packs: string[];
  written: string[];
  skipped: string[];
  errors: InstallError[];
};

export type InstallOptions = {
  targetRoot: string;
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
  const existing = await readConfig(targetRoot);
  const config = existing ?? await seedConfig(targetRoot);
  const installed = await readLock(targetRoot);
  const packs = selectPacks(model, targetRoot, config.packs, new Set(Object.keys(installed?.files ?? {})));

  const planned = await planFiles(model, packs, config.commands);
  const lock = installed;
  const managed = new Set(Object.keys(lock?.files ?? {}));
  const refusals: InstallError[] = [];
  const written: string[] = [];
  const skipped: string[] = [];

  for (const file of planned) {
    const escape = escapesTarget(targetRoot, file.target, MANAGED_FILE_KIND);
    if (escape) { refusals.push(escape); continue; }
    const path = join(targetRoot, file.target);
    if (!existsSync(path)) { written.push(file.target); continue; }
    const actual = hashContent(await Bun.file(path).bytes());
    if (actual === hashContent(file.content) && modeLabel(path) === file.mode) { skipped.push(file.target); continue; }
    const recorded = lock?.files[file.target];
    if (options.force || (recorded && recorded.sha256 === actual)) { written.push(file.target); continue; }
    refusals.push(refusal(file.target, managed.has(file.target)));
  }
  if (options.installHooks) {
    const claim = hooksClaimedByAnother(targetRoot);
    if (claim && !options.force) refusals.push(claim);
    for (const [name] of HOOK_GATES) {
      const escape = escapesTarget(targetRoot, `${HOOKS_DIRECTORY}/${name}`, HOOK_KIND);
      if (escape) refusals.push(escape);
    }
  }
  const lockEscape = escapesTarget(targetRoot, LOCK_PATH, "lock");
  if (lockEscape) refusals.push(lockEscape);
  if (refusals.length > 0) return { ok: false, packs, written: [], skipped, errors: refusals };

  const closure = await stageAndCommit(model, targetRoot, planned, written);
  if (closure.length > 0) return { ok: false, packs, written: [], skipped, errors: closure };

  const hooks = options.installHooks ? await installHooks(targetRoot) : { written: [], all: [] };
  written.push(...hooks.written);
  skipped.push(...hooks.all.filter((path) => !hooks.written.includes(path)));
  const entries = await lockEntries(targetRoot, planned, hooks.all);
  await writeLock(targetRoot, buildLock(options.orlyVersion, packs, entries));
  if (!existing) { await writeConfig(targetRoot, config); written.push(CONFIG_PATH); }
  return { ok: true, packs, written: written.sort(), skipped: skipped.sort(), errors: [] };
}

// A committed symlink inside the target repository — planted by that
// repository's own author, not the person running init — otherwise lets a
// managed-file or hook write follow it and land anywhere the invoking user
// can write. Checked up front, before anything is staged, so it reports as
// a normal refusal rather than a mid-write failure; assertWritableInside
// runs again at the actual write as a last-line guard against a target
// that changed underneath the run.
function escapesTarget(targetRoot: string, target: string, kind: string): InstallError | undefined {
  try {
    assertWritableInside(targetRoot, target, kind);
    return undefined;
  } catch (error) {
    return { path: target, message: error instanceof Error ? error.message : String(error), suggestion: "remove or fix the symlink in the target repository before installing" };
  }
}

function refusal(target: string, wasManaged: boolean): InstallError {
  return wasManaged
    ? { path: target, message: "managed file was edited in place since it was installed", suggestion: "revert the edit, or re-run with --force to overwrite it" }
    : { path: target, message: "a file already exists here and orly did not write it", suggestion: "move it aside, or re-run with --force to replace it" };
}

// The payload is written to a scratch directory and only moved into the target
// once every file exists and every reference it names resolves. Reference
// closure runs against the staged tree, so a pack whose façade cites a document
// no selected pack provides is caught before anything lands. The scratch
// directory lives inside the target's own .oracle/ — not the OS tmp dir —
// because `rename(2)` cannot cross a filesystem boundary: an OS tmp dir and
// the target repository are routinely on different filesystems (a mounted
// external drive, a devcontainer's bind-mounted workspace over a tmpfs
// /tmp), and staging there turned every such install into a hard EXDEV
// crash instead of the atomic move this function exists to guarantee.
async function stageAndCommit(model: RulesModel, targetRoot: string, planned: PlannedFile[], written: string[]): Promise<InstallError[]> {
  const stagingParent = join(targetRoot, dirname(LOCK_PATH));
  const stagingParentExisted = existsSync(stagingParent);
  mkdirSync(stagingParent, { recursive: true });
  const stage = mkdtempSync(join(stagingParent, STAGE_PREFIX));

  // A refusal must leave the target exactly as it found it, and staging now
  // lives inside it: remove .oracle/ too if this run is the one that created
  // it and it is still empty on the failure path — a fresh empty directory
  // left behind is as much a footprint as a written file. The success path
  // must NOT run this: .oracle/ is still empty at this point (the caller
  // writes ruleset.lock into it right after stageAndCommit returns), so an
  // unconditional check would delete a directory the next step needs.
  const cleanupStagingParentIfEmpty = () => {
    rmSync(stage, { recursive: true, force: true });
    if (!stagingParentExisted && existsSync(stagingParent) && readdirSync(stagingParent).length === 0) rmSync(stagingParent, { recursive: true, force: true });
  };

  try {
    for (const file of planned) {
      const path = join(stage, file.target);
      mkdirSync(dirname(path), { recursive: true });
      await Bun.write(path, file.content);
      applyMode(path, file.mode);
    }
    const markdown = planned.filter((file) => extname(file.target) === MARKDOWN_EXTENSION).map((file) => join(stage, file.target));
    const missing = await referenceClosureErrors(stage, markdown);
    if (missing.length > 0) {
      cleanupStagingParentIfEmpty();
      return missing.map((message) => ({ path: AGENTS_FILENAME, message, suggestion: "select the pack that provides the cited file, or amend the citation" }));
    }

    const targets = new Set(written);
    for (const file of planned.filter((candidate) => targets.has(candidate.target))) {
      assertWritableInside(targetRoot, file.target, MANAGED_FILE_KIND);
      const destination = join(targetRoot, file.target);
      mkdirSync(dirname(destination), { recursive: true });
      renameSync(join(stage, file.target), destination);
      applyMode(destination, file.mode);
    }
    rmSync(stage, { recursive: true, force: true });
    return [];
  } catch (error) {
    cleanupStagingParentIfEmpty();
    throw error;
  }
}

// A hooksPath already pointing somewhere other than what init installs is
// someone else's setup — retargeting it silently would disable whatever
// ran there before. init only overrides its own prior installs (the same
// directory name) or an unset config, matching the idempotent-rerun case.
function hooksClaimedByAnother(targetRoot: string): InstallError | undefined {
  const result = Bun.spawnSync([GIT_COMMAND, GIT_REPO_FLAG, targetRoot, GIT_CONFIG_SUBCOMMAND, "--get", HOOKS_PATH_KEY], { stdout: PIPE_OUTPUT, stderr: PIPE_OUTPUT, env: UNSCOPED_ENVIRONMENT });
  if (result.exitCode !== 0) return undefined;
  const existing = result.stdout.toString().trim();
  if (existing === "" || existing === HOOKS_DIRECTORY) return undefined;
  return { path: HOOKS_PATH_KEY, message: `already set to '${existing}', not the directory this install manages`, suggestion: "run with --no-hooks to leave it alone, or --force to retarget it" };
}

// Hooks are generated, never copied: this repository's own hooks run `make
// audit` and `bin/orly verify`, neither of which exists in a consumer. What a
// consumer needs is the gate engine, reached through the binary that installed
// it — with a PATH fallback so a relocated checkout still resolves.
async function installHooks(targetRoot: string): Promise<{ written: string[]; all: string[] }> {
  for (const [name] of HOOK_GATES) assertWritableInside(targetRoot, `${HOOKS_DIRECTORY}/${name}`, HOOK_KIND);
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
  runGit(targetRoot, [GIT_CONFIG_SUBCOMMAND, HOOKS_PATH_KEY, HOOKS_DIRECTORY]);
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
async function planFiles(model: RulesModel, packs: string[], commands: Record<string, string[][]>): Promise<PlannedFile[]> {
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
  const rendered = await new Renderer(model).renderText(packs, commands);
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
