import { existsSync } from "node:fs";
import { dirname, extname, isAbsolute, join, relative, resolve } from "node:path";

import { OrlyError } from "./model";

const PACK_LINE = /^(.*?)[ \t]*<!--[ \t]*oracle-packs:([^>]+)[ \t]*-->[ \t]*$/;
const PACK_START = /^[ \t]*<!--[ \t]*oracle-packs:start ([^>]+)[ \t]*-->[ \t]*$/;
const PACK_END = /^[ \t]*<!--[ \t]*oracle-packs:end[ \t]*-->[ \t]*$/;
const MARKDOWN_LINK = /\[[^\]]*\]\(([^)]+)\)/g;
const DISPATCH_REFERENCE = /dispatch\/[A-Za-z0-9_.-]+\.md/g;
const NEWLINE = "\n";

export function renderProfileText(
  content: string,
  selectedPacks: Set<string>,
  knownPacks: Set<string>,
  source: string,
): string {
  return walkPackMarkers(content, selectedPacks, knownPacks, source, false).join(NEWLINE).trim();
}

// Managed documents keep marker lines verbatim so the source profile's
// self-render stays byte-stable; only excluded lines are dropped.
export function filterManagedText(
  content: string,
  selectedPacks: Set<string>,
  knownPacks: Set<string>,
  source: string,
): string {
  return walkPackMarkers(content, selectedPacks, knownPacks, source, true).join(NEWLINE);
}

function walkPackMarkers(
  content: string,
  selectedPacks: Set<string>,
  knownPacks: Set<string>,
  source: string,
  keepMarkers: boolean,
): string[] {
  const rendered: string[] = [];
  let activeBlock: string[] | undefined;
  let includeBlock = true;
  const lines = content.split(/\r?\n/);
  for (const [index, line] of lines.entries()) {
    const lineNumber = index + 1;
    const start = line.match(PACK_START);
    if (start) {
      if (activeBlock) throw new OrlyError(`${source}:${lineNumber}: nested orly pack block`);
      activeBlock = packNames(start[1] ?? "", knownPacks, source, lineNumber);
      includeBlock = activeBlock.some((name) => selectedPacks.has(name));
      if (keepMarkers && includeBlock) rendered.push(line);
      continue;
    }
    if (PACK_END.test(line)) {
      if (!activeBlock) throw new OrlyError(`${source}:${lineNumber}: unmatched orly pack block end`);
      if (keepMarkers && includeBlock) rendered.push(line);
      activeBlock = undefined;
      includeBlock = true;
      continue;
    }
    if (activeBlock && !includeBlock) continue;
    const match = line.match(PACK_LINE);
    if (match) {
      const names = packNames(match[2] ?? "", knownPacks, source, lineNumber);
      if (names.some((name) => selectedPacks.has(name))) rendered.push(keepMarkers ? line : (match[1] ?? "").trimEnd());
      continue;
    }
    rendered.push(line);
  }
  if (activeBlock) throw new OrlyError(`${source}: unclosed orly pack block`);
  return rendered;
}

export async function referenceClosureErrors(
  outputRoot: string,
  renderedPaths: string[],
): Promise<string[]> {
  const errors = new Set<string>();
  const root = resolve(outputRoot);
  for (const sourcePath of renderedPaths.filter((path) => extname(path) === ".md").sort()) {
    const relativeSource = relative(outputRoot, sourcePath).replaceAll("\\", "/");
    const content = await Bun.file(sourcePath).text();
    for (const [index, line] of content.split(/\r?\n/).entries()) {
      const lineNumber = index + 1;
      for (const match of line.matchAll(MARKDOWN_LINK)) {
        const rawTarget = match[1] ?? "";
        const target = markdownTarget(rawTarget);
        if (!target) continue;
        const resolved = resolve(dirname(sourcePath), target);
        if (!isBelow(resolved, root)) errors.add(`snapshot reference escapes repository: ${relativeSource}:${lineNumber} -> ${rawTarget}`);
        else if (!existsSync(resolved)) errors.add(`missing snapshot reference: ${relativeSource}:${lineNumber} -> ${rawTarget}`);
      }
      for (const target of line.matchAll(DISPATCH_REFERENCE)) {
        const path = target[0];
        if (!existsSync(join(outputRoot, path))) errors.add(`missing dispatch reference: ${relativeSource}:${lineNumber} -> ${path}`);
      }
    }
  }
  return [...errors].sort();
}

function packNames(value: string, knownPacks: Set<string>, source: string, lineNumber: number): string[] {
  const names = value.split(",").map((name) => name.trim()).filter(Boolean);
  if (names.length === 0) throw new OrlyError(`${source}:${lineNumber}: orly pack marker must name a pack`);
  const unknown = names.filter((name) => !knownPacks.has(name)).sort();
  if (unknown.length > 0) throw new OrlyError(`${source}:${lineNumber}: unknown orly pack marker: ${unknown.join(", ")}`);
  return names;
}

function markdownTarget(rawTarget: string): string | undefined {
  const first = rawTarget.trim().split(/\s+/, 1)[0]?.replace(/^<|>$/g, "") ?? "";
  const target = decodeURIComponent(first.split("#", 1)[0] ?? "");
  if (!target || isAbsolute(target) || /^(https?:|mailto:|app:)/.test(target)) return undefined;
  return target;
}

function isBelow(path: string, root: string): boolean {
  const candidate = relative(root, path);
  return candidate === "" || (!candidate.startsWith("..") && !isAbsolute(candidate));
}
