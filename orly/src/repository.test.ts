import { afterEach, describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

import { RulesModel } from "./model";
import { doctorAgentHomes, linkAgentHomes } from "./repository";

const ROOT = resolve(import.meta.dir, "../..");
const temporaryDirectories: string[] = [];

afterEach(() => {
  for (const path of temporaryDirectories.splice(0)) rmSync(path, { recursive: true, force: true });
});

describe("agent-home links", () => {
  test("retargets dotfiles-owned links at the root rules and passes doctor", async () => {
    const model = await RulesModel.load(ROOT);
    const generated = join(ROOT, "AGENTS.md");
    const home = temporaryDirectory();
    mkdirSync(join(home, ".codex"), { recursive: true });
    symlinkSync(join(ROOT, "docs/TEMPLATE.md"), join(home, ".codex/AGENTS.md"));

    await linkAgentHomes(model, home, generated);

    expect(await doctorAgentHomes(model, home, generated)).toEqual([]);
  });

  test("refuses to replace a real agent-home file", async () => {
    const model = await RulesModel.load(ROOT);
    const home = temporaryDirectory();
    mkdirSync(join(home, ".codex"), { recursive: true });
    await Bun.write(join(home, ".codex/AGENTS.md"), "hand-written\n");

    expect(linkAgentHomes(model, home)).rejects.toThrow("refusing to replace agent-home file");
  });
});

function temporaryDirectory(): string {
  const path = mkdtempSync(join(tmpdir(), "orly-repository-test-"));
  temporaryDirectories.push(path);
  return path;
}
