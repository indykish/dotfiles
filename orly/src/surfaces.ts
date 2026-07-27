import { isObject, JsonObject, stringArray } from "./model";

const PIPE_OUTPUT = "pipe";
const DEFAULT_BRANCHES = ["main", "master"];
const ORIGIN_PREFIX = "origin/";
const SURFACES_FIELD = "surfaces";
const USER_FIELD = "user";
const DOCS_FIELD = "docs";
const SPEC_TREE = /^docs\/v[0-9]+\//;
const TEST_PATH = /(^|\/)tests?\/|\.test\.|_test\.|\.spec\./;
const MARKDOWN = /\.(md|mdx)$/;
// One fixed source-extension set across every repo: handlers (.zig), CLI and
// UI TypeScript, OpenAPI YAML, scripts. A fixed set keeps the check identical
// everywhere instead of drifting per profile.
const SOURCE_EXTENSIONS = /\.(zig|ts|tsx|js|jsx|mjs|py|rs|go|sh|sql|yaml|yml|json|toml)$/;

export type SurfaceReport = {
  changed: string[];
  code: string[];
  userSurface: string[];
  docs: string[];
};

// Classify the branch diff once per inspection; every criterion reads this
// report instead of running its own git commands.
export function classifyBranch(root: string, profile: JsonObject): SurfaceReport {
  const changed = branchDiff(root);
  const user = surfacePrefixes(profile, USER_FIELD);
  const docs = surfacePrefixes(profile, DOCS_FIELD);
  return {
    changed,
    code: changed.filter(isCode),
    userSurface: changed.filter((path) => isUserSurface(path, user)),
    docs: changed.filter((path) => isDocs(path, docs)),
  };
}

export function isCode(path: string): boolean {
  return !MARKDOWN.test(path) && (SOURCE_EXTENSIONS.test(path) || TEST_PATH.test(path));
}

// User surface: a profile-declared prefix, a real source file, and not a test —
// a test-only change under a user prefix must not demand a docs edit, or the
// gate trains everyone to distrust it.
export function isUserSurface(path: string, prefixes: string[]): boolean {
  if (!prefixes.some((prefix) => path.startsWith(prefix))) return false;
  return SOURCE_EXTENSIONS.test(path) && !TEST_PATH.test(path) && !MARKDOWN.test(path);
}

// Docs: a profile-declared prefix, but never the spec tree — every milestone
// edits its own spec, so counting docs/v*/ would make the check auto-pass.
export function isDocs(path: string, prefixes: string[]): boolean {
  if (SPEC_TREE.test(path)) return false;
  return prefixes.some((prefix) => path.startsWith(prefix));
}

export function branchDiff(root: string): string[] {
  const base = defaultMergeBase(root);
  if (!base) return [];
  const output = gitOutput(root, ["diff", "--name-only", `${base}..HEAD`]);
  return output.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
}

export function defaultMergeBase(root: string): string {
  for (const branch of defaultBranchCandidates(root)) {
    const base = gitOutput(root, ["merge-base", branch, "HEAD"]);
    if (base) return base;
  }
  return "";
}

function defaultBranchCandidates(root: string): string[] {
  const candidates: string[] = [];
  const head = gitOutput(root, ["rev-parse", "--abbrev-ref", "origin/HEAD"]);
  if (head.startsWith(ORIGIN_PREFIX)) candidates.push(head);
  for (const name of DEFAULT_BRANCHES) candidates.push(`${ORIGIN_PREFIX}${name}`, name);
  return candidates;
}

function surfacePrefixes(profile: JsonObject, field: string): string[] {
  const surfaces = profile[SURFACES_FIELD];
  if (!isObject(surfaces) || !(field in surfaces)) return [];
  return stringArray(surfaces[field], `profile ${String(profile.name)} ${SURFACES_FIELD}.${field}`);
}

function gitOutput(root: string, command: string[]): string {
  const result = Bun.spawnSync(["git", ...command], { cwd: root, stdout: PIPE_OUTPUT, stderr: PIPE_OUTPUT });
  return result.exitCode === 0 ? result.stdout.toString().trim() : "";
}
