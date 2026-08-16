import { Criterion, CriterionContext, criterion, gitOutput, runCommand, Verdict } from "./criteria_support";
import { branchDiff, defaultMergeBase } from "./surfaces";

const OPEN_QUESTION = "[?]";
const PRODUCT_CLARITY_HEADING = "## Product Clarity";
const DIMENSION_PREFIX = "- **Dimension ";
const DONE_MARKER = "DONE";
const SPEC_GATE_SCRIPT = "audits/spec-template.sh";
const NO_SPEC_SKIP = "skipped — no active spec (quality gates still apply)";

const SPEC_GATE = "spec.gate";
const SPEC_OPEN_QUESTIONS = "spec.open-questions";
const SPEC_PRODUCT_CLARITY = "spec.product-clarity";
const SPEC_DIMENSIONS = "spec.dimensions";
const SPEC_MOVED = "spec.moved";
const SPEC_BASELINE = "spec.baseline";
const SPEC_ORDERING = "spec.ordering";
const SPEC_DEFERRALS = "spec.deferrals";
const STATUS_DONE = "Status: DONE";
const BASELINE_HEADER = "Test Baseline:";
const INDY_ACK = "> Indy (";
// deferred/deferral(s) only — never Zig's defer/errdefer keywords.
const DEFERRAL_CLAIM = /\bdeferr(ed|al|als)\b/i;
const SPEC_TREE_FILE = /^docs\/v[^/]+\/.+\.md$/;

// Wrap a spec-reading criterion: no active spec → skip-pass with the reason
// printed, so quality gates still run on spec-less (ad-hoc) branches.
function specCriterion(name: string, evaluate: (context: CriterionContext) => Verdict): Criterion {
  return criterion(name, (context) => {
    if (!context.specText || !context.specPath) return { ok: true, detail: NO_SPEC_SKIP };
    return evaluate(context);
  });
}

export function specGate(): Criterion {
  return specCriterion(SPEC_GATE, (context) => runCommand(context.root, ["bash", SPEC_GATE_SCRIPT, "--file", context.specPath ?? ""]));
}

export function openQuestions(): Criterion {
  return specCriterion(SPEC_OPEN_QUESTIONS, (context) => {
    const hits = specLines(context).filter((line) => line.includes(OPEN_QUESTION));
    return { ok: hits.length === 0, detail: hits.length === 0 ? "no open questions" : `${hits.length} line(s) still carry ${OPEN_QUESTION}` };
  });
}

export function productClarity(): Criterion {
  return specCriterion(SPEC_PRODUCT_CLARITY, (context) => {
    const present = specLines(context).some((line) => line.startsWith(PRODUCT_CLARITY_HEADING));
    return { ok: present, detail: present ? "section present" : `missing ${PRODUCT_CLARITY_HEADING}` };
  });
}

export function specDimensions(): Criterion {
  return specCriterion(SPEC_DIMENSIONS, (context) => {
    const dimensions = specLines(context).filter((line) => line.trimStart().startsWith(DIMENSION_PREFIX));
    const open = dimensions.filter((line) => !line.includes(DONE_MARKER));
    return {
      ok: open.length === 0,
      detail: open.length === 0
        ? `${dimensions.length} dimension(s) marked ${DONE_MARKER}`
        : `${open.length} of ${dimensions.length} not ${DONE_MARKER}: ${dimensionLabels(open)}`,
    };
  });
}

// Closed-spec follow-through (the CHORE(close) blind spot): Status: DONE must
// mean the spec actually sits under done/ AND was moved there on this branch.
export function specMoved(): Criterion {
  return specCriterion(SPEC_MOVED, (context) => {
    if (!statusDone(context)) return { ok: true, detail: "Status not DONE — the move is not yet due" };
    if (!context.specClosed) return { ok: false, detail: "Status: DONE but the spec still lives under active/ — CHORE(close) moves it to done/ before the PR" };
    const moved = branchDiff(context.root).includes(context.specPath ?? "");
    return moved
      ? { ok: true, detail: "moved to done/ on this branch" }
      : { ok: false, detail: "spec sits under done/ but this branch never moved it" };
  });
}

export function specBaseline(): Criterion {
  return specCriterion(SPEC_BASELINE, (context) => {
    const present = specLines(context).some((line) => line.includes(BASELINE_HEADER));
    return present
      ? { ok: true, detail: "Test Baseline recorded" }
      : { ok: false, detail: `no \`${BASELINE_HEADER}\` line in the spec header — CHORE(open) records it before any code` };
  });
}

// "No code until the 4 steps committed": the branch's oldest commit must
// carry a spec file. A first commit of pure code means CHORE(open) never ran.
export function specOrdering(): Criterion {
  return specCriterion(SPEC_ORDERING, (context) => {
    const base = defaultMergeBase(context.root);
    if (!base) return { ok: true, detail: "no merge base — ordering unknowable here" };
    const first = gitOutput(context.root, ["log", "--reverse", "--format=%H", `${base}..HEAD`]).split(/\r?\n/)[0] ?? "";
    if (!first) return { ok: true, detail: "no branch commits yet" };
    const files = gitOutput(context.root, ["show", "--name-only", "--format=", first]).split(/\r?\n/).filter(Boolean);
    const carriesSpec = files.some((file) => SPEC_TREE_FILE.test(file));
    return carriesSpec
      ? { ok: true, detail: `first branch commit ${first.slice(0, 8)} carries the spec` }
      : { ok: false, detail: `first branch commit ${first.slice(0, 8)} carries no spec file — CHORE(open)'s 4 steps commit before any code` };
  });
}

// A "deferred to follow-up" claim requires the Indy-acked verbatim quote in
// the spec; agent-unilateral deferral is incomplete scope, not deferral.
export function specDeferrals(): Criterion {
  return specCriterion(SPEC_DEFERRALS, (context) => {
    const claims = specLines(context).filter((line) => DEFERRAL_CLAIM.test(line) && !line.includes(INDY_ACK));
    if (claims.length === 0) return { ok: true, detail: "no deferral claims" };
    const acked = specLines(context).some((line) => line.includes(INDY_ACK));
    return acked
      ? { ok: true, detail: `${claims.length} deferral line(s), Indy ack quote present` }
      : { ok: false, detail: `${claims.length} deferral line(s) with no "${INDY_ACK}" ack quote — agent-unilateral deferral is incomplete scope` };
  });
}

function statusDone(context: CriterionContext): boolean {
  return specLines(context).some((line) => line.replaceAll("*", "").replace(/\s+/g, " ").includes(STATUS_DONE));
}

function specLines(context: CriterionContext): string[] {
  return (context.specText ?? "").split(/\r?\n/);
}

function dimensionLabels(lines: string[]): string {
  return lines.map((line) => line.trim().slice(DIMENSION_PREFIX.length).split("*")[0]?.trim() ?? "?").join(", ");
}
