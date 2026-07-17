import {
  chmodSync,
  lstatSync,
  mkdirSync,
  mkdtempSync,
  readlinkSync,
  realpathSync,
  rmSync,
  symlinkSync,
  unlinkSync,
} from "node:fs";
import { homedir, tmpdir } from "node:os";
import { dirname, isAbsolute, join, relative, resolve } from "node:path";

import { isString, OrlyError, readJsonObject, RulesModel, stringArray } from "./model";
import { Renderer } from "./render";

const AGENT_HOME_TARGETS = [
  ".claude/CLAUDE.md",
  ".codex/AGENTS.md",
  ".config/opencode/AGENTS.md",
  ".amp/AGENTS.md",
];
const PROJECT_INSTRUCTIONS = "AGENTS.project.md";
const RULESET_LOCK = ".oracle/ruleset.lock";
const DEFAULT_PROJECT_INSTRUCTIONS = "# Repository instructions\n\nAdd repository commands, terminology, architecture triggers, and local safety rules.\n";
const PROFILE_PATH = ".oracle/profile.json";
const MANIFEST_PATH = ".oracle/managed-files.json";
const AGENTS_PATH = "AGENTS.md";
const GLOBAL_PROFILE = "global";
const GLOBAL_RULES_PATH = "orly/generated/global/AGENTS.md";
const MANAGED_FILES_LABEL = "managed files";
const PIPE_OUTPUT = "pipe";
const NEWLINE = "\n";
const PARENT_SEGMENT = "..";

export function repositoryPath(model: RulesModel, name: string): string {
  const value = model.repository(name).path;
  if (!isString(value)) throw new OrlyError(`repository ${name} path must be a string`);
  const expanded = value === "~" ? homedir() : value.startsWith("~/") ? join(homedir(), value.slice(2)) : value;
  return resolve(expanded);
}

export function gitStatus(projectRoot: string): string[] {
  const result = Bun.spawnSync(["git", "status", "--porcelain=v1", "-uall"], { cwd: projectRoot, stdout: PIPE_OUTPUT, stderr: PIPE_OUTPUT });
  if (result.exitCode !== 0) throw new OrlyError(`not a Git repository: ${projectRoot}`);
  return result.stdout.toString().split(/\r?\n/).filter(Boolean);
}

export async function syncRepository(model: RulesModel, name: string): Promise<string[]> {
  const projectRoot = repositoryPath(model, name);
  requireCleanRepository(projectRoot, "sync");
  const isSourceRepository = projectRoot === resolve(model.root);
  const projectInstructions = join(projectRoot, PROJECT_INSTRUCTIONS);
  if (!isSourceRepository && !pathExists(projectInstructions)) throw new OrlyError(`${projectInstructions} is required before replacing AGENTS.md`);
  const profileName = profileFor(model, name);
  const renderer = new Renderer(model);
  const renderedRoot = mkdtempSync(join(tmpdir(), "orly-sync-"));
  try {
    await renderer.render(profileName, renderedRoot, isSourceRepository ? undefined : projectRoot);
    const managedFiles = await managedPaths(renderedRoot);
    const priorManaged = await priorManagedFiles(projectRoot, profileName, renderer);
    const errors = await replacementErrors(model, projectRoot, renderedRoot, managedFiles, priorManaged);
    if (errors.length > 0) throw new OrlyError(errors.join(NEWLINE));
    return await copyManagedFiles(projectRoot, renderedRoot, managedFiles);
  } finally {
    rmSync(renderedRoot, { recursive: true, force: true });
  }
}

export async function adoptRepository(model: RulesModel, name: string): Promise<string[]> {
  const projectRoot = repositoryPath(model, name);
  requireCleanRepository(projectRoot, "adoption");
  if (pathExists(join(projectRoot, RULESET_LOCK)) || pathExists(join(projectRoot, MANIFEST_PATH))) {
    throw new OrlyError(`repository is already adopted; run \`orly sync ${name}\``);
  }
  const projectPath = join(projectRoot, PROJECT_INSTRUCTIONS);
  const agentsPath = join(projectRoot, AGENTS_PATH);
  const projectInput = await projectInstructionsForAdoption(model, projectPath, agentsPath);
  const tempRoot = mkdtempSync(join(tmpdir(), "orly-adopt-"));
  try {
    const inputRoot = join(tempRoot, "input");
    mkdirSync(inputRoot);
    await Bun.write(join(inputRoot, PROJECT_INSTRUCTIONS), projectInput.content);
    const renderedRoot = join(tempRoot, "rendered");
    await new Renderer(model).render(profileFor(model, name), renderedRoot, inputRoot);
    const managedFiles = await managedPaths(renderedRoot);
    const errors = await adoptionReplacementErrors(model, projectRoot, renderedRoot, managedFiles);
    if (errors.length > 0) throw new OrlyError(errors.join(NEWLINE));
    const copied: string[] = [];
    if (projectInput.create) {
      await Bun.write(projectPath, projectInput.content);
      copied.push(PROJECT_INSTRUCTIONS);
    }
    copied.push(...await copyManagedFiles(projectRoot, renderedRoot, managedFiles));
    return copied.sort();
  } finally {
    rmSync(tempRoot, { recursive: true, force: true });
  }
}

export async function doctorRepository(model: RulesModel, name: string): Promise<string[]> {
  const root = repositoryPath(model, name);
  if (!pathExists(root)) return [`repository is missing: ${root}`];
  return new Renderer(model).verifyLock(root, profileFor(model, name));
}

export async function syncGlobal(model: RulesModel): Promise<string[]> {
  const generatedRoot = join(model.root, "orly/generated/global");
  await new Renderer(model).render(GLOBAL_PROFILE, generatedRoot);
  return linkAgentHomes(model);
}

export async function linkAgentHomes(
  model: RulesModel,
  home = homedir(),
  generated = join(model.root, GLOBAL_RULES_PATH),
): Promise<string[]> {
  if (!pathExists(generated)) throw new OrlyError(`generated global rules are missing: ${generated}`);
  const errors = await new Renderer(model).verifyLock(dirname(generated), GLOBAL_PROFILE);
  if (errors.length > 0) throw new OrlyError(`generated global rules are stale:\n${errors.join(NEWLINE)}`);
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
  generated = join(model.root, GLOBAL_RULES_PATH),
): Promise<string[]> {
  if (!pathExists(generated)) return [`generated global rules are missing: ${generated}`];
  const errors = await new Renderer(model).verifyLock(dirname(generated), GLOBAL_PROFILE);
  for (const target of agentHomeTargets(home)) {
    if (!pathExists(target) || !lstatSync(target).isSymbolicLink()) errors.push(`agent-home instructions are not linked: ${target}`);
    else if (linkDestination(target) !== realpathSync(generated)) errors.push(`agent-home instructions point elsewhere: ${target}`);
  }
  return errors;
}

function requireCleanRepository(projectRoot: string, action: string): void {
  if (!pathExists(projectRoot)) throw new OrlyError(`repository is missing: ${projectRoot}`);
  const dirty = gitStatus(projectRoot);
  if (dirty.length > 0) throw new OrlyError(`repository must be clean before ${action}:\n${dirty.join(NEWLINE)}`);
}

function profileFor(model: RulesModel, name: string): string {
  const profile = model.repository(name).profile;
  if (!isString(profile)) throw new OrlyError(`repository ${name} profile must be a string`);
  return profile;
}

async function managedPaths(renderedRoot: string): Promise<string[]> {
  const manifest = await readJsonObject(join(renderedRoot, MANIFEST_PATH));
  return [...stringArray(manifest.files, MANAGED_FILES_LABEL), RULESET_LOCK];
}

async function projectInstructionsForAdoption(
  model: RulesModel,
  projectPath: string,
  agentsPath: string,
): Promise<{ content: string; create: boolean }> {
  if (pathExists(projectPath)) {
    if (lstatSync(projectPath).isSymbolicLink()) throw new OrlyError(`refusing symbolic repository instructions: ${projectPath}`);
    if (!lstatSync(projectPath).isFile()) throw new OrlyError(`repository instructions must be a file: ${projectPath}`);
    if (pathExists(agentsPath) && !lstatSync(agentsPath).isSymbolicLink()) throw new OrlyError("both AGENTS.md and AGENTS.project.md contain repository instructions");
    return { content: await Bun.file(projectPath).text(), create: false };
  }
  if (pathExists(agentsPath)) {
    if (lstatSync(agentsPath).isSymbolicLink()) {
      const target = realpathSync(agentsPath);
      if (!isBelow(target, realpathSync(model.root))) throw new OrlyError(`refusing AGENTS.md link outside dotfiles: ${agentsPath}`);
      return { content: DEFAULT_PROJECT_INSTRUCTIONS, create: true };
    }
    if (!lstatSync(agentsPath).isFile()) throw new OrlyError(`AGENTS.md must be a file: ${agentsPath}`);
    return { content: await Bun.file(agentsPath).text(), create: true };
  }
  return { content: DEFAULT_PROJECT_INSTRUCTIONS, create: true };
}

async function adoptionReplacementErrors(
  model: RulesModel,
  projectRoot: string,
  renderedRoot: string,
  managedFiles: string[],
): Promise<string[]> {
  const errors: string[] = [];
  for (const relativePath of managedFiles) {
    const target = join(projectRoot, relativePath);
    if (!pathExists(target) || relativePath === AGENTS_PATH) continue;
    const rendered = join(renderedRoot, relativePath);
    if (relativePath === PROFILE_PATH && !lstatSync(target).isSymbolicLink() && await sameBytes(target, rendered)) continue;
    if (lstatSync(target).isSymbolicLink() && isBelow(realpathSync(target), realpathSync(model.root))) continue;
    errors.push(`refusing to replace unmanaged path: ${relativePath}`);
  }
  return errors;
}

async function replacementErrors(
  model: RulesModel,
  projectRoot: string,
  renderedRoot: string,
  managedFiles: string[],
  priorManaged: Set<string>,
): Promise<string[]> {
  const errors: string[] = [];
  for (const relativePath of managedFiles) {
    const target = join(projectRoot, relativePath);
    if (!isBelow(resolve(target), resolve(projectRoot))) {
      errors.push(`managed path escapes repository: ${relativePath}`);
      continue;
    }
    if (!pathExists(target) || priorManaged.has(relativePath)) continue;
    const rendered = join(renderedRoot, relativePath);
    if (lstatSync(target).isSymbolicLink() && isBelow(realpathSync(target), realpathSync(model.root))) continue;
    if (relativePath === PROFILE_PATH && !lstatSync(target).isSymbolicLink() && await sameBytes(target, rendered)) continue;
    errors.push(`refusing to replace unmanaged path: ${relativePath}`);
  }
  return errors;
}

async function priorManagedFiles(projectRoot: string, profile: string, renderer: Renderer): Promise<Set<string>> {
  const manifestPath = join(projectRoot, MANIFEST_PATH);
  const lockPath = join(projectRoot, RULESET_LOCK);
  if (!pathExists(manifestPath) && !pathExists(lockPath)) return new Set();
  if (!pathExists(manifestPath) || !pathExists(lockPath)) throw new OrlyError("repository has a partial Orly snapshot");
  const errors = (await renderer.verifyLock(projectRoot, profile)).filter((error) => error !== "repository ruleset is behind its current profile");
  if (errors.length > 0) throw new OrlyError(`existing Orly snapshot is not safe to replace:\n${errors.join(NEWLINE)}`);
  const manifest = await readJsonObject(manifestPath);
  const files = stringArray(manifest.files, MANAGED_FILES_LABEL);
  for (const path of files) if (isAbsolute(path) || path.split(/[\\/]/).includes(PARENT_SEGMENT)) throw new OrlyError(`managed path escapes repository: ${path}`);
  return new Set([...files, RULESET_LOCK]);
}

async function copyManagedFiles(projectRoot: string, renderedRoot: string, managedFiles: string[]): Promise<string[]> {
  for (const relativePath of managedFiles) {
    const source = join(renderedRoot, relativePath);
    const target = join(projectRoot, relativePath);
    mkdirSync(dirname(target), { recursive: true });
    if (pathExists(target) && lstatSync(target).isSymbolicLink()) unlinkSync(target);
    await Bun.write(target, Bun.file(source));
    chmodSync(target, lstatSync(source).mode & 0o777);
  }
  return [...managedFiles].sort();
}

function agentHomeTargets(home: string): string[] {
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

function isBelow(path: string, root: string): boolean {
  const candidate = relative(root, path);
  return candidate === "" || (!candidate.startsWith(PARENT_SEGMENT) && !isAbsolute(candidate));
}

async function sameBytes(left: string, right: string): Promise<boolean> {
  const leftBytes = new Uint8Array(await Bun.file(left).arrayBuffer());
  const rightBytes = new Uint8Array(await Bun.file(right).arrayBuffer());
  return leftBytes.length === rightBytes.length && leftBytes.every((value, index) => value === rightBytes[index]);
}
