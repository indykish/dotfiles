import { mkdirSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

import { RulesModel } from "./model";
import { Renderer } from "./render";

const PASS_RESULT = "pass";
const FAIL_RESULT = "fail";

export type VerificationCheck = {
  name: string;
  result: typeof PASS_RESULT | typeof FAIL_RESULT;
  detail?: string;
};

export async function verifyAllProfiles(model: RulesModel): Promise<VerificationCheck[]> {
  model.validate();
  const checks: VerificationCheck[] = [];
  const renderer = new Renderer(model);
  for (const profileName of Object.keys(model.profiles).sort()) {
    const firstRoot = mkdtempSync(join(tmpdir(), `orly-${profileName}-a-`));
    const secondRoot = mkdtempSync(join(tmpdir(), `orly-${profileName}-b-`));
    try {
      const first = await renderer.render(profileName, firstRoot);
      const second = await renderer.render(profileName, secondRoot);
      checks.push({
        name: `render.${profileName}.idempotent`,
        result: JSON.stringify(first) === JSON.stringify(second) ? PASS_RESULT : FAIL_RESULT,
      });
    } finally {
      rmSync(firstRoot, { recursive: true, force: true });
      rmSync(secondRoot, { recursive: true, force: true });
    }
  }
  const outputs: Record<string, string> = {
    "generated.global.current": join(model.root, "orly/generated/global"),
    "generated.dotfiles.current": model.root,
  };
  for (const [name, root] of Object.entries(outputs)) {
    const errors = await renderer.verifyLock(root);
    checks.push({ name, result: errors.length === 0 ? PASS_RESULT : FAIL_RESULT, detail: errors.join("; ") });
  }
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
    registry_digest: await model.registryDigest(),
    result: checks.every((check) => check.result === PASS_RESULT) ? PASS_RESULT : FAIL_RESULT,
    checks,
    llm_result: languageModelResult,
    created_at: new Date().toISOString().replace(/\.\d{3}Z$/, "+00:00"),
  };
  await Bun.write(path, `${JSON.stringify(evidence, null, 2)}\n`);
  return path;
}
