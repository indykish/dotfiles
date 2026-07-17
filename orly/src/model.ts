import { chmodSync, existsSync, lstatSync, readdirSync } from "node:fs";
import { basename, join } from "node:path";

import { validateActiveRule, validateCommands, validateRelativePath } from "./validation";

export type JsonObject = Record<string, unknown>;

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

export class OrlyError extends Error {}

export class RulesModel {
  readonly root: string;
  readonly registry: JsonObject;
  readonly profiles: Record<string, JsonObject>;
  readonly repositories: JsonObject;

  constructor(
    root: string,
    registry: JsonObject,
    profiles: Record<string, JsonObject>,
    repositories: JsonObject,
  ) {
    this.root = root;
    this.registry = registry;
    this.profiles = profiles;
    this.repositories = repositories;
  }

  static async load(root: string): Promise<RulesModel> {
    const registry = await readJsonObject(join(root, "orly/registry.json"));
    const profiles: Record<string, JsonObject> = {};
    const profileRoot = join(root, "orly/profiles");
    for (const filename of readdirSync(profileRoot).filter((name) => name.endsWith(JSON_EXTENSION)).sort()) {
      profiles[basename(filename, JSON_EXTENSION)] = await readJsonObject(join(profileRoot, filename));
    }
    const repositories = await readJsonObject(join(root, "orly/repositories.json"));
    return new RulesModel(root, registry, profiles, repositories);
  }

  validate(): void {
    const errors: string[] = [];
    this.validateRegistry(errors);
    this.validateProfiles(errors);
    this.validateRules(errors);
    this.validateRepositories(errors);
    if (errors.length > 0) throw new OrlyError(errors.join("\n"));
  }

  profile(name: string): JsonObject {
    const profile = this.profiles[name];
    if (!profile) throw new OrlyError(`unknown profile: ${name}`);
    return profile;
  }

  repository(name: string): JsonObject {
    const repositories = objectValue(this.repositories.repositories, REPOSITORIES_LABEL);
    const repository = repositories[name];
    if (!isObject(repository)) throw new OrlyError(`unknown repository: ${name}`);
    return repository;
  }

  registryDigest(): Promise<string> {
    const values: Array<[string, unknown]> = [
      [REGISTRY_LABEL, this.registry],
      [REPOSITORIES_LABEL, this.repositories],
      ...Object.keys(this.profiles).sort().map((name): [string, unknown] => [`profile:${name}`, this.profiles[name]]),
    ];
    return this.contentDigest(values, this.allRuleSources());
  }

  profileDigest(profileName: string): Promise<string> {
    const profile = this.profile(profileName);
    const packs = objectValue(this.registry.packs, REGISTRY_PACKS_LABEL);
    const selectedPacks: JsonObject = {};
    for (const name of stringArray(profile.packs, `profile ${profileName} packs`)) selectedPacks[name] = packs[name];
    const rules = objectArray(this.registry.rules, REGISTRY_RULES_LABEL);
    const selectedRules = rules.filter((rule) => isString(rule.pack) && rule.pack in selectedPacks);
    const subset = {
      schema_version: this.registry.schema_version,
      core_documents: this.registry.core_documents,
      packs: selectedPacks,
      rules: selectedRules,
    };
    const sources = this.implementationSources();
    for (const source of stringArray(this.registry.core_documents, CORE_DOCUMENTS_LABEL)) sources.add(source);
    for (const pack of Object.values(selectedPacks)) {
      if (!isObject(pack)) continue;
      for (const file of objectArray(pack.managed_files, MANAGED_FILES_LABEL)) {
        if (isString(file.source)) sources.add(file.source);
      }
    }
    for (const rule of selectedRules) addFixtureSources(rule, sources);
    return this.contentDigest([[REGISTRY_LABEL, subset], ["profile", profile]], sources);
  }

  private allRuleSources(): Set<string> {
    const sources = this.implementationSources();
    for (const source of stringArray(this.registry.core_documents, CORE_DOCUMENTS_LABEL)) sources.add(source);
    const packs = objectValue(this.registry.packs, REGISTRY_PACKS_LABEL);
    for (const pack of Object.values(packs)) {
      if (!isObject(pack)) continue;
      for (const file of objectArray(pack.managed_files, MANAGED_FILES_LABEL)) {
        if (isString(file.source)) sources.add(file.source);
      }
    }
    for (const rule of objectArray(this.registry.rules, REGISTRY_RULES_LABEL)) addFixtureSources(rule, sources);
    return sources;
  }

  private implementationSources(): Set<string> {
    const sources = new Set<string>([
      "bin/orly",
      "orly/bun.lock",
      "orly/package.json",
      "orly/tsconfig.json",
    ]);
    for (const filename of readdirSync(join(this.root, "orly/src")).filter((name) => name.endsWith(".ts") && !name.endsWith(".test.ts")).sort()) {
      sources.add(`orly/src/${filename}`);
    }
    for (const filename of readdirSync(join(this.root, "orly/schemas")).filter((name) => name.endsWith(JSON_EXTENSION)).sort()) {
      sources.add(`orly/schemas/${filename}`);
    }
    return sources;
  }

  private async contentDigest(values: Array<[string, unknown]>, sources: Set<string>): Promise<string> {
    const hasher = new Bun.CryptoHasher("sha256");
    for (const [label, value] of values) hasher.update(`${label}\0${stableJson(value)}\0`);
    for (const source of [...sources].sort()) {
      const path = join(this.root, source);
      if (!(await Bun.file(path).exists())) continue;
      hasher.update(`${source}\0${normalizedMode(path).toString(8).padStart(4, "0")}\0`);
      hasher.update(await Bun.file(path).arrayBuffer());
      hasher.update("\0");
    }
    return hasher.digest("hex");
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

  private validateProfiles(errors: string[]): void {
    const packs = isObject(this.registry.packs) ? this.registry.packs : {};
    for (const [name, profile] of Object.entries(this.profiles)) {
      if (profile.schema_version !== 1) errors.push(`profile ${name} schema_version must equal 1`);
      if (profile.name !== name) errors.push(`profile ${name} name must match its filename`);
      if (!Array.isArray(profile.packs)) {
        errors.push(`profile ${name} packs must be an array`);
        continue;
      }
      const owners = new Map<string, string>();
      for (const packName of profile.packs) {
        if (!isString(packName) || !isObject(packs[packName])) {
          errors.push(`profile ${name} selects unknown pack ${String(packName)}`);
          continue;
        }
        for (const extension of stringArray(packs[packName].extensions, `pack ${packName} extensions`)) {
          const previous = owners.get(extension);
          if (previous) errors.push(`profile ${name} extension ${extension} has two owners: ${previous}, ${packName}`);
          owners.set(extension, packName);
        }
      }
      validateCommands(name, profile.commands, errors);
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
      if (value.state === ACTIVE_STATE) validateActiveRule(key, value, this.profiles, this.root, errors);
    }
  }

  private validateRepositories(errors: string[]): void {
    if (this.repositories.schema_version !== 1) errors.push("repositories schema_version must equal 1");
    if (!isObject(this.repositories.repositories)) {
      errors.push("repositories must be an object");
      return;
    }
    for (const [name, value] of Object.entries(this.repositories.repositories)) {
      if (!isObject(value)) {
        errors.push(`repository ${name} must be an object`);
        continue;
      }
      if (!isString(value.profile) || !this.profiles[value.profile]) errors.push(`repository ${name} selects unknown profile`);
      if (!isString(value.path) || value.path.length === 0) errors.push(`repository ${name} path must be a string`);
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

export function normalizedMode(path: string): number {
  return (lstatSync(path).mode & 0o111) === 0 ? NON_EXECUTABLE_MODE : EXECUTABLE_MODE;
}

export function stableJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(",")}]`;
  if (isObject(value)) return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableJson(value[key])}`).join(",")}}`;
  return JSON.stringify(value);
}

export function setNormalizedMode(path: string, source: string): void {
  chmodSync(path, normalizedMode(source));
}

function addFixtureSources(rule: JsonObject, sources: Set<string>): void {
  if (!isObject(rule.fixtures)) return;
  for (const paths of Object.values(rule.fixtures)) if (Array.isArray(paths)) for (const path of paths) if (isString(path)) sources.add(path);
}
