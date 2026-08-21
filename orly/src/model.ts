import { chmodSync, existsSync, lstatSync, readdirSync, readlinkSync, realpathSync } from "node:fs";
import { basename, dirname, isAbsolute, join, relative, resolve } from "node:path";

import { validateActiveRule, validateRelativePath } from "./validation";

export type JsonObject = Record<string, unknown>;

const HASH_ALGORITHM = "sha256";
const HASH_ENCODING = "hex";
const MODE_EXECUTABLE = "0755";
const MODE_REGULAR = "0644";
const EXECUTABLE_BITS = 0o755;
const OCTAL = 8;

const NON_EXECUTABLE_MODE = 0o644;
const EXECUTABLE_MODE = 0o755;
const JSON_EXTENSION = ".json";
const REPOSITORIES_LABEL = "repositories";
const REGISTRY_LABEL = "registry";
const REGISTRY_PACKS_LABEL = "registry packs";
const REGISTRY_RULES_LABEL = "registry rules";
const CORE_DOCUMENTS_LABEL = "core documents";
const MANAGED_FILES_LABEL = "managed files";
const ACTIVE_STATE = "active";
const PARENT_SEGMENT = "..";

export class OrlyError extends Error {}

// The one boundary check every filesystem-writing path in orly relies on —
// previously three independent copies (repository.ts, references.ts, and an
// install.ts symlink-escape check found by adversarial review), which is
// itself a risk: a security check that can drift out of sync across copies.
export function isBelow(path: string, root: string): boolean {
  const candidate = relative(root, path);
  return candidate === "" || (!candidate.startsWith(PARENT_SEGMENT) && !isAbsolute(candidate));
}

// A destination a caller has not yet written may not exist; find the nearest
// ancestor that does, so its real (symlink-resolved) location can be checked
// before anything is created under it.
export function nearestExistingAncestor(path: string): string {
  let current = path;
  while (!existsSync(current)) {
    const parent = dirname(current);
    if (parent === current) return current;
    current = parent;
  }
  return current;
}

// A committed symlink inside a target repository — planted by that
// repository's own author, not the invoking user — otherwise lets any
// materialising write follow it and land outside the target entirely.
// mkdirSync/writeFile/rename all follow symlinks silently; this must run
// before every one of them, not just once at the top of an operation.
export function assertWritableInside(root: string, relativeTarget: string, kind: string): void {
  const destination = join(root, relativeTarget);
  const ancestor = nearestExistingAncestor(dirname(destination));
  const resolvedAncestor = realpathSync(ancestor);
  const resolvedRoot = realpathSync(root);
  if (!isBelow(resolvedAncestor, resolvedRoot)) {
    throw new OrlyError(`refusing to write ${kind} outside the target repository: ${relativeTarget} resolves through a symlink to ${resolvedAncestor}`);
  }
  // The destination itself, not only the directory holding it. A symlinked
  // *file* — a committed `AGENTS.md -> ../../elsewhere` — has an ancestor
  // squarely inside the repository, so the check above passes and the write
  // follows the link out. Every write orly makes goes through here, so this is
  // the one place the file case has to be caught.
  if (!isSymbolicLink(destination)) return;
  const resolvedDestination = safeRealpath(destination);
  if (resolvedDestination !== undefined && !isBelow(resolvedDestination, resolvedRoot)) {
    throw new OrlyError(`refusing to write ${kind} outside the target repository: ${relativeTarget} is a symlink to ${resolvedDestination}`);
  }
}

function isSymbolicLink(path: string): boolean {
  try {
    return lstatSync(path).isSymbolicLink();
  } catch {
    return false;
  }
}

// A dangling link resolves nowhere; judge it by where it points, not where it
// lands, so a link to a not-yet-created file outside the repository still fails.
function safeRealpath(path: string): string | undefined {
  try {
    return realpathSync(path);
  } catch {
    return resolve(dirname(path), readlinkSync(path));
  }
}

export class RulesModel {
  readonly root: string;
  readonly registry: JsonObject;

  constructor(
    root: string,
    registry: JsonObject,
  ) {
    this.root = root;
    this.registry = registry;
  }

  static async load(root: string): Promise<RulesModel> {
    const registry = await readJsonObject(join(root, "orly/registry.json"));
    return new RulesModel(root, registry);
  }

  validate(): void {
    const errors: string[] = [];
    this.validateRegistry(errors);
    this.validateRules(errors);
    if (errors.length > 0) throw new OrlyError(errors.join("\n"));
  }

  private validateRegistry(errors: string[]): void {
    if (this.registry.schema_version !== 1) errors.push("registry schema_version must equal 1");
    const documents = this.registry.core_documents;
    if (!Array.isArray(documents) || documents.length === 0) errors.push("registry core_documents must be a non-empty array");
    else for (const document of documents) this.requireSource(document, "core document", errors);
    const packs = this.registry.packs;
    if (!isObject(packs) || Object.keys(packs).length === 0) {
      errors.push("registry packs must be a non-empty object");
      return;
    }
    for (const [name, value] of Object.entries(packs)) this.validatePack(name, value, errors);
  }

  private validatePack(name: string, value: unknown, errors: string[]): void {
    if (!isObject(value)) {
      errors.push(`pack ${name} must be an object`);
      return;
    }
    if (!Array.isArray(value.extensions)) errors.push(`pack ${name} extensions must be an array`);
    if (!Array.isArray(value.managed_files)) {
      errors.push(`pack ${name} managed_files must be an array`);
      return;
    }
    for (const file of value.managed_files) {
      if (!isObject(file)) {
        errors.push(`pack ${name} managed file must be an object`);
        continue;
      }
      this.requireSource(file.source, `pack ${name}`, errors);
      validateRelativePath(file.target, `pack ${name} managed target`, errors);
    }
  }

  private validateRules(errors: string[]): void {
    if (!Array.isArray(this.registry.rules)) {
      errors.push("registry rules must be an array");
      return;
    }
    const packs = isObject(this.registry.packs) ? this.registry.packs : {};
    const keys = new Set<string>();
    for (const value of this.registry.rules) {
      if (!isObject(value)) {
        errors.push("registry rule must be an object");
        continue;
      }
      const key = value.key;
      if (!isString(key) || key.length === 0) {
        errors.push("registry rule key must be a string");
        continue;
      }
      if (keys.has(key)) errors.push(`duplicate rule key: ${key}`);
      keys.add(key);
      if (![ACTIVE_STATE, "draft", "retired"].includes(String(value.state))) errors.push(`rule ${key} has invalid state`);
      if (!isString(value.pack) || !(value.pack in packs)) errors.push(`rule ${key} selects unknown pack ${String(value.pack)}`);
      if (value.state === ACTIVE_STATE) validateActiveRule(key, value, this.root, errors);
    }
  }

  private requireSource(source: unknown, label: string, errors: string[]): void {
    if (!isString(source) || source.length === 0) {
      errors.push(`${label} source must be a string`);
      return;
    }
    validateRelativePath(source, `${label} source`, errors);
    if (!existsSync(join(this.root, source))) errors.push(`${label} source is missing: ${source}`);
  }
}

// The published package ships no repositories.json — it names only this
// machine's own checkouts, which a stranger's install has no use for and
// this repo's owner has no reason to publish. Its absence is the normal
// case for anyone but the engine's own maintainer, not a broken install.
export async function readJsonObject(path: string): Promise<JsonObject> {
  try {
    const value: unknown = await Bun.file(path).json();
    if (!isObject(value)) throw new Error("root value is not an object");
    return value;
  } catch (error) {
    throw new OrlyError(`cannot read JSON object from ${path}: ${String(error)}`);
  }
}

export function isObject(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function isString(value: unknown): value is string {
  return typeof value === "string";
}

export function objectValue(value: unknown, label: string): JsonObject {
  if (!isObject(value)) throw new OrlyError(`${label} must be an object`);
  return value;
}

export function stringArray(value: unknown, label: string): string[] {
  if (!Array.isArray(value) || !value.every(isString)) throw new OrlyError(`${label} must be an array of strings`);
  return value;
}

export function objectArray(value: unknown, label: string): JsonObject[] {
  if (!Array.isArray(value) || !value.every(isObject)) throw new OrlyError(`${label} must be an array of objects`);
  return value;
}

// What a materialised file is, reduced to the two properties that decide
// whether it still is what orly wrote: its bytes and whether it is runnable.
export function hashContent(content: string | Uint8Array): string {
  return new Bun.CryptoHasher(HASH_ALGORITHM).update(content).digest(HASH_ENCODING);
}

export function modeLabel(path: string): string {
  return normalizedMode(path) === EXECUTABLE_BITS ? MODE_EXECUTABLE : MODE_REGULAR;
}

export function applyMode(path: string, mode: string): void {
  chmodSync(path, Number.parseInt(mode, OCTAL));
}

export function normalizedMode(path: string): number {
  return (lstatSync(path).mode & 0o111) === 0 ? NON_EXECUTABLE_MODE : EXECUTABLE_MODE;
}


export function setNormalizedMode(path: string, source: string): void {
  chmodSync(path, normalizedMode(source));
}

