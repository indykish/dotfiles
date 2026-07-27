import { existsSync, readdirSync } from "node:fs";
import { join, relative } from "node:path";

import { criteriaFor, CriterionResult } from "./criteria";
import { OrlyError, RulesModel } from "./model";

const PENDING = "PENDING";
const PLANNED = "PLANNED";
const EXECUTING = "EXECUTING";
const VERIFIED = "VERIFIED";
const PR_READY = "PR_READY";
const DONE = "DONE";
const PARKED = "PARKED";
const IN_PROGRESS_STATUS = "IN_PROGRESS";

export const STATES = [PENDING, PLANNED, EXECUTING, VERIFIED, PR_READY, DONE, PARKED] as const;
export type State = (typeof STATES)[number];

// The advance graph is derived from one ordered walk, so a state cannot be
// wired into the chain in one place and forgotten in another. v1 stops at
// PR_READY: PR_READY -> DONE (CHORE(close)) and the LAND/SHIP states stay
// prose-manual until the v2 spec supplies real external signals.
const WALK: State[] = [PENDING, PLANNED, EXECUTING, VERIFIED, PR_READY];
const ADVANCES: Partial<Record<State, State>> = Object.fromEntries(
  WALK.slice(0, -1).map((state, index) => [state, WALK[index + 1]]),
);

const STATUS_FOR: Record<State, string> = {
  [PENDING]: PENDING,
  [PLANNED]: IN_PROGRESS_STATUS,
  [EXECUTING]: IN_PROGRESS_STATUS,
  [VERIFIED]: IN_PROGRESS_STATUS,
  [PR_READY]: IN_PROGRESS_STATUS,
  [DONE]: DONE,
  [PARKED]: IN_PROGRESS_STATUS,
};

const TRANSITIONS_HEADING = "## Transitions";
const STATUS_PREFIX = "**Status:**";
const ARROW = "→";
const ROW_PATTERN = /^\|([^|]+)\|([^|]+)\|([^|]+)\|(.*)\|\s*$/;
const OVERRIDE_PATTERN = /^OVERRIDE\(([^)]+)\)/;
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const ACTIVE_DIRECTORY = "active";
const DOCS_DIRECTORY = "docs";
const PROTOTYPE_PATTERN = /^v\d+$/;
const MARKDOWN_EXTENSION = ".md";
const NEWLINE = "\n";
const AGENT_ACTOR = "agent";
const GREEN_VERDICT = "green";
const TIMESTAMP_HEADER = "Timestamp";
const SEPARATOR_CELL = "---";

export type TransitionRow = { timestamp: string; from: State; to: State; actor: string; verdict: string };

export type LifecycleView = {
  specPath: string;
  state: State;
  target?: State;
  results: CriterionResult[];
  overridden: string[];
};

export function activeSpecPath(root: string): string {
  const specs = activeSpecPaths(root);
  if (specs.length === 0) throw new OrlyError("no spec under docs/v*/active/ — author one with the kishore-spec-new skill, then CHORE(open) it");
  if (specs.length > 1) throw new OrlyError(`more than one active spec; the engine drives one stream:\n${specs.join(NEWLINE)}`);
  return specs[0] ?? "";
}

export function parseTransitions(text: string): TransitionRow[] {
  const rows: TransitionRow[] = [];
  for (const line of transitionLines(text)) {
    const match = line.match(ROW_PATTERN);
    if (!match) continue;
    const timestamp = cell(match[1]);
    if (timestamp === TIMESTAMP_HEADER || timestamp.startsWith(SEPARATOR_CELL)) continue;
    const [from, to] = splitStates(cell(match[2]));
    // A data row that will not parse is state corruption, not noise to skip:
    // the log is the only state record, so silently ignoring it would invent a state.
    if (!from || !to) throw new OrlyError(`unreadable transition row: ${line}`);
    rows.push({ timestamp, from, to, actor: cell(match[3]), verdict: cell(match[4]) });
  }
  return rows;
}

export function currentState(rows: TransitionRow[]): State {
  const last = rows[rows.length - 1];
  return last ? last.to : PENDING;
}

// An override is scoped to the state it was recorded in: scan back from the
// tail and stop at the first real advance.
export function activeOverrides(rows: TransitionRow[]): string[] {
  const names: string[] = [];
  for (let index = rows.length - 1; index >= 0; index -= 1) {
    const row = rows[index];
    if (!row) break;
    if (row.from !== row.to) break;
    const match = row.verdict.match(OVERRIDE_PATTERN);
    if (match?.[1]) names.push(match[1]);
  }
  return names;
}

export function appendTransition(text: string, row: TransitionRow): string {
  const lines = text.split(/\r?\n/);
  const heading = lines.findIndex((line) => line.trim() === TRANSITIONS_HEADING);
  if (heading < 0) throw new OrlyError(`spec has no "${TRANSITIONS_HEADING}" section`);
  let insert = heading + 1;
  for (let index = heading + 1; index < lines.length; index += 1) {
    const line = lines[index] ?? "";
    if (line.startsWith("#")) break;
    if (line.trimStart().startsWith("|")) insert = index + 1;
  }
  lines.splice(insert, 0, renderRow(row));
  return lines.join(NEWLINE);
}

export function applyStatus(text: string, state: State): string {
  return text.split(/\r?\n/)
    .map((line) => (line.startsWith(STATUS_PREFIX) ? `${STATUS_PREFIX} ${STATUS_FOR[state]}` : line))
    .join(NEWLINE);
}

export function formatTimestamp(date: Date): string {
  const hours = date.getHours() % 12 === 0 ? 12 : date.getHours() % 12;
  const meridiem = date.getHours() < 12 ? "AM" : "PM";
  return `${MONTHS[date.getMonth()]} ${pad(date.getDate())}, ${date.getFullYear()}: ${pad(hours)}:${pad(date.getMinutes())} ${meridiem}`;
}

export async function inspect(model: RulesModel, root: string, acceptDirty = false, explicit?: State): Promise<LifecycleView> {
  const specPath = activeSpecPath(root);
  const specText = await Bun.file(specPath).text();
  const rows = parseTransitions(specText);
  const state = currentState(rows);
  const target = explicit ?? ADVANCES[state];
  const overridden = activeOverrides(rows);
  if (!target) return { specPath, state, results: [], overridden };
  const context = { root, specPath: relative(root, specPath), specText, model, acceptDirty };
  const results = criteriaFor(target, context).map((criterion) => {
    const result = criterion.evaluate(context);
    if (result.ok || !overridden.includes(result.name)) return result;
    return { name: result.name, ok: true, detail: `overridden — ${result.detail}` };
  });
  return { specPath, state, target, results, overridden };
}

export async function advance(model: RulesModel, root: string, now: Date, acceptDirty = false): Promise<{ view: LifecycleView; advanced: boolean }> {
  const view = await inspect(model, root, acceptDirty);
  if (!view.target) return { view, advanced: false };
  if (view.results.some((result) => !result.ok)) return { view, advanced: false };
  const used = view.overridden.filter((name) => view.results.some((result) => result.name === name));
  const verdict = used.length === 0 ? GREEN_VERDICT : `${GREEN_VERDICT} (${used.length} override(s): ${used.join(", ")})`;
  await writeRow(view.specPath, { timestamp: formatTimestamp(now), from: view.state, to: view.target, actor: AGENT_ACTOR, verdict });
  return { view, advanced: true };
}

export async function record(root: string, now: Date, actor: string, to: State | undefined, verdict: string): Promise<{ specPath: string; from: State; to: State }> {
  const specPath = activeSpecPath(root);
  const rows = parseTransitions(await Bun.file(specPath).text());
  const from = currentState(rows);
  const target = to ?? from;
  await writeRow(specPath, { timestamp: formatTimestamp(now), from, to: target, actor, verdict: sanitize(verdict) });
  return { specPath, from, to: target };
}

export function isState(value: string): value is State {
  return (STATES as readonly string[]).includes(value);
}

async function writeRow(specPath: string, row: TransitionRow): Promise<void> {
  const text = await Bun.file(specPath).text();
  await Bun.write(specPath, applyStatus(appendTransition(text, row), row.to));
}

function activeSpecPaths(root: string): string[] {
  const docs = join(root, DOCS_DIRECTORY);
  if (!existsSync(docs)) return [];
  const found: string[] = [];
  for (const prototype of readdirSync(docs).filter((name) => PROTOTYPE_PATTERN.test(name)).sort()) {
    const directory = join(docs, prototype, ACTIVE_DIRECTORY);
    if (!existsSync(directory)) continue;
    for (const file of readdirSync(directory).filter((name) => name.endsWith(MARKDOWN_EXTENSION)).sort()) found.push(join(directory, file));
  }
  return found;
}

function transitionLines(text: string): string[] {
  const lines = text.split(/\r?\n/);
  const heading = lines.findIndex((line) => line.trim() === TRANSITIONS_HEADING);
  if (heading < 0) return [];
  const collected: string[] = [];
  for (let index = heading + 1; index < lines.length; index += 1) {
    const line = lines[index] ?? "";
    if (line.startsWith("#")) break;
    if (line.trimStart().startsWith("|")) collected.push(line.trim());
  }
  return collected;
}

function splitStates(value: string): [State | undefined, State | undefined] {
  const parts = value.split(ARROW).map((part) => part.trim());
  const from = parts[0] ?? "";
  const to = parts[1] ?? "";
  return [isState(from) ? from : undefined, isState(to) ? to : undefined];
}

function renderRow(row: TransitionRow): string {
  return `| ${row.timestamp} | ${row.from} ${ARROW} ${row.to} | ${row.actor} | ${row.verdict} |`;
}

function sanitize(value: string): string {
  return value.replaceAll("|", "/").replace(/\s+/g, " ").trim();
}

function cell(value: string | undefined): string {
  return (value ?? "").trim();
}

function pad(value: number): string {
  return String(value).padStart(2, "0");
}
