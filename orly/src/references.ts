import { existsSync } from "node:fs";
import { dirname, extname, isAbsolute, join, relative, resolve } from "node:path";

import { isBelow, OrlyError } from "./model";

const PACK_LINE = /^(.*?)[ \t]*<!--[ \t]*oracle-packs:([^>]+)[ \t]*-->[ \t]*$/;
const PACK_START = /^[ \t]*<!--[ \t]*oracle-packs:start ([^>]+)[ \t]*-->[ \t]*$/;
const PACK_END = /^[ \t]*<!--[ \t]*oracle-packs:end[ \t]*-->[ \t]*$/;
const CODE_FENCE = /^[ \t]*(?:```|~~~)/;
const MARKDOWN_LINK = /\[[^\]]*\]\(([^)]+)\)/g;
const DISPATCH_REFERENCE = /dispatch\/[A-Za-z0-9_.-]+\.md/g;
const COMMENT_OPEN = "<!--";
const COMMENT_CLOSE = "-->";
const NEWLINE = "\n";

export function renderProfileText(
  content: string,
  selectedPacks: Set<string>,
  knownPacks: Set<string>,
  source: string,
): string {
  return walkPackMarkers(content, selectedPacks, knownPacks, source).join(NEWLINE).trim();
}

function walkPackMarkers(
  content: string,
  selectedPacks: Set<string>,
  knownPacks: Set<string>,
  source: string,
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
      continue;
    }
    if (PACK_END.test(line)) {
      if (!activeBlock) throw new OrlyError(`${source}:${lineNumber}: unmatched orly pack block end`);
      activeBlock = undefined;
      includeBlock = true;
      continue;
    }
    if (activeBlock && !includeBlock) continue;
    const match = line.match(PACK_LINE);
    if (match) {
      const names = packNames(match[2] ?? "", knownPacks, source, lineNumber);
      if (names.some((name) => selectedPacks.has(name))) rendered.push((match[1] ?? "").trimEnd());
      continue;
    }
    rendered.push(line);
  }
  if (activeBlock) throw new OrlyError(`${source}: unclosed orly pack block`);
  return rendered;
}

// `fallbackRoot` is the repository the staged tree is about to land in. A file
// the install skipped because its source and target are the same path — the
// engine checkout updating itself — is absent from the stage but present in
// that repository, and a citation of it resolves. Without the fallback, a
// self-update fails closure against files it deliberately left alone.
export async function referenceClosureErrors(
  outputRoot: string,
  renderedPaths: string[],
  fallbackRoot?: string,
): Promise<string[]> {
  const errors = new Set<string>();
  const root = resolve(outputRoot);
  const present = (path: string): boolean =>
    existsSync(path) || (fallbackRoot !== undefined && existsSync(join(fallbackRoot, relative(root, path))));
  for (const sourcePath of renderedPaths.filter((path) => extname(path) === ".md").sort()) {
    const relativeSource = relative(outputRoot, sourcePath).replaceAll("\\", "/");
    const content = await Bun.file(sourcePath).text();
    let inComment = false;
    let inFence = false;
    for (const [index, line] of content.split(/\r?\n/).entries()) {
      const lineNumber = index + 1;
      // A fenced block is a code sample, not prose citing a file. A shell
      // one-liner carrying `sed -E 's#.*[:/]([^:/]+/[^/]+)$#\1#'` matches the
      // markdown-link shape exactly, and grading it demanded a file named
      // after the regex.
      if (CODE_FENCE.test(line)) { inFence = !inFence; continue; }
      if (inFence) continue;
      const commented = inComment;
      inComment = commentStateAfter(line, inComment);
      // A path inside an HTML comment is authoring guidance — `docs/TEMPLATE.md`
      // lists a per-surface menu of dispatch façades a spec author might cite.
      // Grading those as live citations would force every repository to carry
      // every language pack just to satisfy a comment naming the alternatives.
      if (commented || inComment) continue;
      for (const match of line.matchAll(MARKDOWN_LINK)) {
        const rawTarget = match[1] ?? "";
        const target = markdownTarget(rawTarget);
        if (!target) continue;
        const resolved = resolve(dirname(sourcePath), target);
        if (!isBelow(resolved, root)) errors.add(`snapshot reference escapes repository: ${relativeSource}:${lineNumber} -> ${rawTarget}`);
        else if (!present(resolved)) errors.add(`missing snapshot reference: ${relativeSource}:${lineNumber} -> ${rawTarget}`);
      }
      for (const target of line.matchAll(DISPATCH_REFERENCE)) {
        const path = target[0];
        if (!present(join(outputRoot, path))) errors.add(`missing dispatch reference: ${relativeSource}:${lineNumber} -> ${path}`);
      }
    }
  }
  return [...errors].sort();
}

// Whether the line leaves the scanner inside an HTML comment. Pack markers open
// and close on one line, so they never flip the state; a `<!-- tpl:` block that
// runs to a later `-->` does.
function commentStateAfter(line: string, inComment: boolean): boolean {
  let open = inComment;
  for (let index = 0; index < line.length; index += 1) {
    if (!open && line.startsWith(COMMENT_OPEN, index)) { open = true; index += COMMENT_OPEN.length - 1; continue; }
    if (open && line.startsWith(COMMENT_CLOSE, index)) { open = false; index += COMMENT_CLOSE.length - 1; }
  }
  return open;
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
