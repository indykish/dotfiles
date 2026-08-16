import { mkdirSync } from "node:fs";
import { dirname, join } from "node:path";

import { localSelection } from "./config";
import { objectValue, RulesModel } from "./model";
import { Renderer } from "./render";

const PASS_RESULT = "pass";
const FAIL_RESULT = "fail";

export type VerificationCheck = {
  name: string;
  result: typeof PASS_RESULT | typeof FAIL_RESULT;
  detail?: string;
};

// Two proofs: every profile renders the same bytes twice (determinism), and
// the committed root AGENTS.md matches its render (currency). No stored
// hashes — the render itself is the reference.
export async function verifyRenders(model: RulesModel): Promise<VerificationCheck[]> {
  model.validate();
  const checks: VerificationCheck[] = [];
  const renderer = new Renderer(model);
  const local = await localSelection(model, model.root);
  const everything = Object.keys(objectValue(model.registry.packs, "registry packs")).sort();
  for (const [name, packs] of [["local", local.packs], ["all", everything]] as Array<[string, string[]]>) {
    const first = await renderer.renderText(packs, local.commands);
    const second = await renderer.renderText(packs, local.commands);
    checks.push({
      name: `render.${name}.idempotent`,
      result: first === second ? PASS_RESULT : FAIL_RESULT,
    });
  }
  const errors = await renderer.rootErrors(local.packs, local.commands);
  checks.push({ name: "generated.root.current", result: errors.length === 0 ? PASS_RESULT : FAIL_RESULT, detail: errors.join("; ") });
  return checks;
}

export async function writeEvidence(
  model: RulesModel,
  profile: string,
  checks: VerificationCheck[],
  languageModelResult: "pass" | "not-required",
): Promise<string> {
  const path = join(model.root, ".oracle/evidence.json");
  mkdirSync(dirname(path), { recursive: true });
  const commit = Bun.spawnSync(["git", "rev-parse", "HEAD"], { cwd: model.root, stdout: "pipe", stderr: "ignore" });
  const evidence = {
    schema_version: 1,
    profile,
    source_commit: commit.exitCode === 0 ? commit.stdout.toString().trim() : "uncommitted",
    result: checks.every((check) => check.result === PASS_RESULT) ? PASS_RESULT : FAIL_RESULT,
    checks,
    llm_result: languageModelResult,
    created_at: new Date().toISOString().replace(/\.\d{3}Z$/, "+00:00"),
  };
  await Bun.write(path, `${JSON.stringify(evidence, null, 2)}\n`);
  return path;
}
