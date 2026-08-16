import { existsSync } from "node:fs";
import { isAbsolute, join, relative } from "node:path";

import type { JsonObject } from "./model";

export function validateRelativePath(value: unknown, label: string, errors: string[]): void {
  if (!isString(value) || value.length === 0) {
    errors.push(`${label} must be a string`);
    return;
  }
  if (isAbsolute(value) || relative(".", value).split(/[\\/]/).includes("..")) errors.push(`${label} must stay below the output root: ${value}`);
}

// Optional diff-surface prefixes a repository declares: surfaces.user (paths
// whose change demands a docs update) and surfaces.docs (paths that count as
// that update).
export function validateSurfaces(label: string, value: unknown, errors: string[]): void {
  if (value === undefined) return;
  if (!isObject(value)) {
    errors.push(`${label} surfaces must be an object`);
    return;
  }
  for (const [field, prefixes] of Object.entries(value)) {
    if (field !== "user" && field !== "docs") errors.push(`${label} surfaces.${field} is not a known surface`);
    else if (!Array.isArray(prefixes) || !prefixes.every((prefix) => isString(prefix) && prefix.length > 0)) {
      errors.push(`${label} surfaces.${field} must be an array of path prefixes`);
    }
  }
}

export function validateCommands(label: string, value: unknown, errors: string[]): void {
  if (!isObject(value)) {
    errors.push(`${label} commands must be an object`);
    return;
  }
  for (const [name, invocations] of Object.entries(value)) {
    if (!Array.isArray(invocations) || invocations.length === 0) {
      errors.push(`${label} command ${name} must be non-empty`);
      continue;
    }
    for (const invocation of invocations) if (!Array.isArray(invocation) || invocation.length === 0 || !invocation.every((argument) => isString(argument) && argument.length > 0)) errors.push(`${label} command ${name} arguments must be strings`);
  }
}

export function validateActiveRule(
  key: string,
  rule: JsonObject,
  root: string,
  errors: string[],
): void {
  if (rule.decision === "mechanical") {
    validateMechanicalRule(key, rule, root, errors);
    return;
  }
  if (rule.decision === "repository") {
    if (!isString(rule.command) || rule.command.length === 0) errors.push(`repository rule ${key} needs a command name`);
    return;
  }
  if (rule.decision !== "judgment") errors.push(`rule ${key} has invalid decision ${String(rule.decision)}`);
}

function validateMechanicalRule(key: string, rule: JsonObject, root: string, errors: string[]): void {
  if (!Array.isArray(rule.checker) || rule.checker.length === 0) errors.push(`mechanical rule ${key} needs a checker`);
  if (!isObject(rule.fixtures)) {
    errors.push(`mechanical rule ${key} needs fixtures`);
    return;
  }
  for (const kind of ["pass", "fail"]) {
    const fixtures = rule.fixtures[kind];
    if (!Array.isArray(fixtures) || fixtures.length === 0) {
      errors.push(`mechanical rule ${key} needs ${kind} fixtures`);
      continue;
    }
    for (const fixture of fixtures) {
      validateRelativePath(fixture, `rule ${key} ${kind} fixture`, errors);
      if (isString(fixture) && !existsSync(join(root, fixture))) errors.push(`rule ${key} ${kind} fixture source is missing: ${fixture}`);
    }
  }
}

function isObject(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isString(value: unknown): value is string {
  return typeof value === "string";
}
