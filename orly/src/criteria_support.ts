import { RulesModel } from "./model";
import { SurfaceReport } from "./surfaces";

const PIPE_OUTPUT = "pipe";
const NO_OUTPUT = "no output";

export type Verdict = { ok: boolean; detail: string };
export type CriterionResult = Verdict & { name: string };

export type CriterionContext = {
  root: string;
  // Absent when the branch has no spec at all: spec criteria then skip-pass —
  // an ad-hoc bug fix meets quality gates, never a demand to write a spec.
  // A spec closed to done/ on this branch is still discovered (Branch: match)
  // and gates with specClosed set — closing never skips the criteria.
  specPath?: string;
  specText?: string;
  specClosed?: boolean;
  model: RulesModel;
  acceptDirty: boolean;
  surfaces?: SurfaceReport;
};

export type Criterion = { name: string; evaluate: (context: CriterionContext) => CriterionResult };

// The name is written once and stamped onto the verdict, so a criterion can
// never report under a name that disagrees with the one it was registered as.
export function criterion(name: string, evaluate: (context: CriterionContext) => Verdict): Criterion {
  return { name, evaluate: (context) => ({ name, ...evaluate(context) }) };
}

export function runCommand(root: string, command: string[]): Verdict {
  // Profile command surfaces are repository-declared, so a named binary may
  // simply not be installed here. Bun.spawnSync THROWS in that case; a gate
  // must report every criterion as a verdict, never abort the run, so the
  // missing binary becomes a red line naming the command.
  let result;
  try {
    result = Bun.spawnSync(command, { cwd: root, stdout: PIPE_OUTPUT, stderr: PIPE_OUTPUT });
  } catch (error) {
    return { ok: false, detail: `${command[0] ?? "command"} could not be run: ${error instanceof Error ? error.message : String(error)}` };
  }
  if (result.exitCode === 0) return { ok: true, detail: "exit 0" };
  const merged = `${result.stdout.toString()}\n${result.stderr.toString()}`;
  const lines = merged.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
  return { ok: false, detail: `exit ${result.exitCode}: ${lines[lines.length - 1] ?? NO_OUTPUT}` };
}

export function gitOutput(root: string, command: string[]): string {
  const result = Bun.spawnSync(["git", ...command], { cwd: root, stdout: PIPE_OUTPUT, stderr: PIPE_OUTPUT });
  return result.exitCode === 0 ? result.stdout.toString().trim() : "";
}
