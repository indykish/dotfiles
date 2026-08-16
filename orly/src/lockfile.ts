import { chmodSync, existsSync, lstatSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";

import { assertWritableInside, isObject, isString, normalizedMode, objectValue, OrlyError, readJsonObject, stringArray } from "./model";

const ORACLE_DIRECTORY = ".oracle";
export const LOCK_PATH = `${ORACLE_DIRECTORY}/ruleset.lock`;

const LOCK_SCHEMA_VERSION = 1;
const HASH_ALGORITHM = "sha256";
const HASH_ENCODING = "hex";
const MODE_EXECUTABLE = "0755";
const MODE_REGULAR = "0644";
const EXECUTABLE_BITS = 0o755;
const OCTAL = 8;
const JSON_INDENT = 2;
const NEWLINE = "\n";

export type LockEntry = { sha256: string; mode: string };

export type Lockfile = {
  schema_version: number;
  orly_version: string;
  profile: string;
  packs: string[];
  files: Record<string, LockEntry>;
};

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

export function buildLock(orlyVersion: string, profile: string, packs: string[], files: Record<string, LockEntry>): Lockfile {
  return { schema_version: LOCK_SCHEMA_VERSION, orly_version: orlyVersion, profile, packs: [...packs].sort(), files: sortEntries(files) };
}

export function lockPath(targetRoot: string): string {
  return join(targetRoot, LOCK_PATH);
}

export async function readLock(targetRoot: string): Promise<Lockfile | undefined> {
  const path = lockPath(targetRoot);
  if (!existsSync(path)) return undefined;
  const value = await readJsonObject(path);
  if (value.schema_version !== LOCK_SCHEMA_VERSION) throw new OrlyError(`${LOCK_PATH} schema_version must equal ${LOCK_SCHEMA_VERSION}`);
  if (!isString(value.orly_version) || !isString(value.profile)) throw new OrlyError(`${LOCK_PATH} must carry orly_version and profile strings`);
  return {
    schema_version: LOCK_SCHEMA_VERSION,
    orly_version: value.orly_version,
    profile: value.profile,
    packs: stringArray(value.packs, `${LOCK_PATH} packs`),
    files: readEntries(objectValue(value.files, `${LOCK_PATH} files`)),
  };
}

export async function writeLock(targetRoot: string, lock: Lockfile): Promise<string> {
  assertWritableInside(targetRoot, LOCK_PATH, "lock");
  const path = lockPath(targetRoot);
  mkdirSync(dirname(path), { recursive: true });
  await Bun.write(path, `${JSON.stringify(lock, undefined, JSON_INDENT)}${NEWLINE}`);
  return path;
}

// Drift is anything the repository can no longer prove orly put there: a
// managed file edited by hand, made executable, or deleted outright. Reported
// rather than repaired — a silent overwrite is how four weeks of edits vanish.
export async function lockDrift(targetRoot: string, lock: Lockfile): Promise<string[]> {
  const findings: string[] = [];
  for (const [relativePath, entry] of Object.entries(lock.files)) {
    const path = join(targetRoot, relativePath);
    if (!existsSync(path) || !lstatSync(path).isFile()) {
      findings.push(`managed file is missing: ${relativePath} — run \`orly init --force\` to restore it`);
      continue;
    }
    const actual = hashContent(await Bun.file(path).bytes());
    if (actual !== entry.sha256) findings.push(`managed file was edited in place: ${relativePath} — revert it, or run \`orly init --force\` to overwrite`);
    else if (modeLabel(path) !== entry.mode) findings.push(`managed file mode changed: ${relativePath} — expected ${entry.mode}, found ${modeLabel(path)}`);
  }
  return findings.sort();
}

export function staleVersion(lock: Lockfile, installedVersion: string): string | undefined {
  if (lock.orly_version === installedVersion) return undefined;
  return `ruleset is pinned to orly ${lock.orly_version}, installed engine is ${installedVersion} — run \`orly update\``;
}

function readEntries(files: Record<string, unknown>): Record<string, LockEntry> {
  const entries: Record<string, LockEntry> = {};
  for (const [path, value] of Object.entries(files)) {
    if (!isObject(value) || !isString(value.sha256) || !isString(value.mode)) throw new OrlyError(`${LOCK_PATH} entry ${path} must carry sha256 and mode strings`);
    entries[path] = { sha256: value.sha256, mode: value.mode };
  }
  return entries;
}

function sortEntries(files: Record<string, LockEntry>): Record<string, LockEntry> {
  const sorted: Record<string, LockEntry> = {};
  for (const path of Object.keys(files).sort()) {
    const entry = files[path];
    if (entry) sorted[path] = entry;
  }
  return sorted;
}
