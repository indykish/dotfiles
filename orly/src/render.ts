import { chmodSync, lstatSync, mkdirSync, unlinkSync } from "node:fs";
import { dirname, join, relative } from "node:path";

import {
  isObject,
  isString,
  JsonObject,
  normalizedMode,
  objectArray,
  objectValue,
  OrlyError,
  readJsonObject,
  RulesModel,
  stringArray,
} from "./model";
import { referenceClosureErrors, renderProfileText } from "./references";

const NON_EXECUTABLE_MODE = 0o644;
const GLOBAL_PROFILE = "global";
const NEWLINE = "\n";
const REGISTRY_PACKS_LABEL = "registry packs";
const PROFILE_PACKS_LABEL = "profile packs";
const MANAGED_TARGET_LABEL = "managed target";
const MANIFEST_PATH = ".oracle/managed-files.json";
const RULESET_LOCK_PATH = ".oracle/ruleset.lock";
const TABLE_SEPARATOR = "|---|---|";

export class Renderer {
  readonly model: RulesModel;

  constructor(model: RulesModel) {
    this.model = model;
  }

  async render(
    profileName: string,
    outputRoot: string,
    projectRoot?: string,
  ): Promise<Record<string, string>> {
    const profile = this.model.profile(profileName);
    mkdirSync(outputRoot, { recursive: true });
    const renderedPaths: string[] = [];
    const agentsPath = join(outputRoot, "AGENTS.md");
    await writeText(agentsPath, await this.agentsContent(profileName, profile, projectRoot));
    renderedPaths.push(agentsPath);

    for (const managedFile of this.managedFiles(profile)) {
      const sourcePath = join(this.model.root, stringValue(managedFile.source, "managed source"));
      const targetPath = join(outputRoot, stringValue(managedFile.target, MANAGED_TARGET_LABEL));
      await writeBytes(targetPath, await Bun.file(sourcePath).arrayBuffer(), normalizedMode(sourcePath));
      renderedPaths.push(targetPath);
    }
    if (profileName !== GLOBAL_PROFILE) {
      const errors = await referenceClosureErrors(outputRoot, renderedPaths);
      if (errors.length > 0) throw new OrlyError(errors.join(NEWLINE));
    }

    const profilePath = join(outputRoot, ".oracle/profile.json");
    await writeJson(profilePath, profile);
    renderedPaths.push(profilePath);
    const managedPaths = renderedPaths.map((path) => relative(outputRoot, path).replaceAll("\\", "/")).sort();
    managedPaths.push(MANIFEST_PATH);
    managedPaths.sort();
    const manifestPath = join(outputRoot, MANIFEST_PATH);
    await writeJson(manifestPath, { schema_version: 1, profile: profileName, files: managedPaths });
    renderedPaths.push(manifestPath);

    const hashes: Record<string, string> = {};
    const modes: Record<string, string> = {};
    for (const path of renderedPaths.sort()) {
      const relativePath = relative(outputRoot, path).replaceAll("\\", "/");
      hashes[relativePath] = await sha256File(path);
      modes[relativePath] = fileMode(path);
    }
    const lockPath = join(outputRoot, RULESET_LOCK_PATH);
    await writeJson(lockPath, {
      schema_version: 1,
      profile: profileName,
      ruleset_digest: await this.model.profileDigest(profileName),
      files: hashes,
      modes,
    });
    return { ...hashes, [RULESET_LOCK_PATH]: await sha256File(lockPath) };
  }

  async verifyLock(projectRoot: string, expectedProfile?: string): Promise<string[]> {
    const lockPath = join(projectRoot, RULESET_LOCK_PATH);
    if (!(await Bun.file(lockPath).exists())) return ["missing .oracle/ruleset.lock"];
    const lock = await readJsonObject(lockPath);
    const errors: string[] = [];
    if (expectedProfile && lock.profile !== expectedProfile) errors.push(`ruleset profile is ${String(lock.profile)}, expected ${expectedProfile}`);
    const profileName = expectedProfile ?? lock.profile;
    let currentDigest: string | undefined;
    if (isString(profileName)) {
      try {
        currentDigest = await this.model.profileDigest(profileName);
        if (lock.ruleset_digest !== currentDigest) errors.push("repository ruleset is behind its current profile");
      } catch {
        errors.push(`ruleset selects unknown profile: ${profileName}`);
      }
    } else errors.push("ruleset profile must be a string");
    if (!isObject(lock.files)) return ["ruleset lock files must be an object"];
    const modes = isObject(lock.modes) ? lock.modes : undefined;
    if (!modes && currentDigest === lock.ruleset_digest) errors.push("ruleset lock modes must be an object");
    if (modes && !sameKeys(modes, lock.files)) errors.push("ruleset lock modes must match managed files");
    for (const [relativePath, expectedHash] of Object.entries(lock.files)) {
      if (relativePath.split(/[\\/]/).includes("..")) {
        errors.push(`managed path escapes repository: ${relativePath}`);
        continue;
      }
      const managedPath = join(projectRoot, relativePath);
      if (!(await Bun.file(managedPath).exists())) {
        errors.push(`missing managed file: ${relativePath}`);
        continue;
      }
      if (lstatSync(managedPath).isSymbolicLink()) {
        errors.push(`managed file is a symbolic link: ${relativePath}`);
        continue;
      }
      if (await sha256File(managedPath) !== expectedHash) errors.push(`managed file changed: ${relativePath}`);
      if (modes && modes[relativePath] !== fileMode(managedPath)) errors.push(`managed file mode changed: ${relativePath} (${fileMode(managedPath)}, expected ${String(modes[relativePath])})`);
    }
    return errors;
  }

  private async agentsContent(profileName: string, profile: JsonObject, projectRoot?: string): Promise<string> {
    const digest = await this.model.profileDigest(profileName);
    const sections = [
      `> **Generated by \`orly\`.**\n> Profile: \`${profileName}\`. Ruleset digest: \`${digest}\`.\n> Do not edit. Update the source rule or \`AGENTS.project.md\`, then run\n> \`orly sync <REPOSITORY>\`.`,
    ];
    const packs = objectValue(this.model.registry.packs, REGISTRY_PACKS_LABEL);
    const selected = new Set(stringArray(profile.packs, `profile ${profileName} packs`));
    if (profileName === GLOBAL_PROFILE) for (const name of Object.keys(packs)) selected.add(name);
    const known = new Set(Object.keys(packs));
    for (const document of stringArray(this.model.registry.core_documents, "core documents")) {
      sections.push(renderProfileText(await Bun.file(join(this.model.root, document)).text(), selected, known, document));
    }
    sections.push(this.packTable(profile));
    sections.push(this.commandTable(profile));
    if (projectRoot) {
      const projectPath = join(projectRoot, "AGENTS.project.md");
      if (await Bun.file(projectPath).exists()) sections.push((await Bun.file(projectPath).text()).trim());
    }
    return `${sections.filter(Boolean).join("\n\n---\n\n")}\n`;
  }

  private packTable(profile: JsonObject): string {
    const rows = ["# Selected rule packs", "", "| Pack | Extensions |", TABLE_SEPARATOR];
    const packs = objectValue(this.model.registry.packs, REGISTRY_PACKS_LABEL);
    const selected = stringArray(profile.packs, PROFILE_PACKS_LABEL);
    if (selected.length === Object.keys(packs).length) rows.push("| All registered packs | Full source inventory |");
    else for (const name of selected) {
      const pack = objectValue(packs[name], `pack ${name}`);
      const extensions = stringArray(pack.extensions, `pack ${name} extensions`).join(", ") || "path or action trigger";
      rows.push(`| \`${name}\` | ${extensions} |`);
    }
    if (selected.length === 0) rows.push("| None | Global behavior only |");
    return rows.join(NEWLINE);
  }

  private commandTable(profile: JsonObject): string {
    const rows = ["# Repository commands", "", "| Responsibility | Commands |", TABLE_SEPARATOR];
    const commands = objectValue(profile.commands, "profile commands");
    for (const name of Object.keys(commands).sort()) {
      const invocations = commands[name];
      if (!Array.isArray(invocations)) continue;
      const rendered = invocations.map((invocation) => Array.isArray(invocation) ? `\`${invocation.map((argument) => quoteArgument(String(argument))).join(" ")}\`` : "").join("<br>");
      rows.push(`| \`${name}\` | ${rendered} |`);
    }
    if (Object.keys(commands).length === 0) rows.push("| None | Supplied by the active repository profile |");
    return rows.join(NEWLINE);
  }

  private managedFiles(profile: JsonObject): JsonObject[] {
    const byTarget = new Map<string, JsonObject>();
    const packs = objectValue(this.model.registry.packs, REGISTRY_PACKS_LABEL);
    for (const name of stringArray(profile.packs, PROFILE_PACKS_LABEL)) {
      const pack = objectValue(packs[name], `pack ${name}`);
      for (const file of objectArray(pack.managed_files, `pack ${name} managed files`)) {
        const target = stringValue(file.target, MANAGED_TARGET_LABEL);
        const previous = byTarget.get(target);
        if (previous && previous.source !== file.source) throw new OrlyError(`profile ${String(profile.name)} maps two sources to ${target}`);
        byTarget.set(target, file);
      }
    }
    return [...byTarget.entries()].sort(([left], [right]) => left.localeCompare(right)).map(([, file]) => file);
  }
}

async function writeBytes(path: string, content: ArrayBuffer, mode = NON_EXECUTABLE_MODE): Promise<void> {
  mkdirSync(dirname(path), { recursive: true });
  if (await Bun.file(path).exists() && lstatSync(path).isSymbolicLink()) unlinkSync(path);
  await Bun.write(path, content);
  chmodSync(path, mode);
}

async function writeText(path: string, content: string): Promise<void> {
  await writeBytes(path, new TextEncoder().encode(content).buffer);
}

async function writeJson(path: string, value: unknown): Promise<void> {
  await writeText(path, `${JSON.stringify(value, null, 2)}\n`);
}

async function sha256File(path: string): Promise<string> {
  const hasher = new Bun.CryptoHasher("sha256");
  hasher.update(await Bun.file(path).arrayBuffer());
  return hasher.digest("hex");
}

function fileMode(path: string): string {
  return (lstatSync(path).mode & 0o777).toString(8).padStart(4, "0");
}

function stringValue(value: unknown, label: string): string {
  if (!isString(value) || value.length === 0) throw new OrlyError(`${label} must be a string`);
  return value;
}

function sameKeys(left: JsonObject, right: JsonObject): boolean {
  return JSON.stringify(Object.keys(left).sort()) === JSON.stringify(Object.keys(right).sort());
}

function quoteArgument(value: string): string {
  return /^[A-Za-z0-9_./:=+-]+$/.test(value) ? value : `'${value.replaceAll("'", `'\\''`)}'`;
}
