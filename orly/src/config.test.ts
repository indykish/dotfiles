import { describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

import { CONFIG_PATH, readConfig, readConfigSync, seedConfig, selectPacks } from "./config";
import { RulesModel } from "./model";

const ROOT = resolve(import.meta.dir, "../..");
const RUST_SOURCE = "src/lib.rs";
const SHELL_PACK = "language.shell";
const RUST_PACK = "language.rust";
const ZIG_PACK = "language.zig";

function scratch(): string {
  const root = mkdtempSync(join(tmpdir(), "orly-config-"));
  temporary.push(root);
  return root;
}
const temporary: string[] = [];

function writeConfigText(root: string, body: unknown): void {
  mkdirSync(join(root, ".oracle"), { recursive: true });
  writeFileSync(join(root, CONFIG_PATH), JSON.stringify(body));
}

describe("selectPacks", () => {
  test("selects a language pack only when the repository carries that language", async () => {
    const model = await RulesModel.load(ROOT);
    const root = scratch();
    mkdirSync(join(root, "src"), { recursive: true });
    writeFileSync(join(root, RUST_SOURCE), "pub fn main() {}\n");

    const packs = selectPacks(model, root, []);

    expect(packs).toContain(RUST_PACK);
    expect(packs).not.toContain(ZIG_PACK);
  });

  test("never infers an opt-in pack, and takes it when the config names it", async () => {
    const model = await RulesModel.load(ROOT);
    const root = scratch();

    expect(selectPacks(model, root, [])).not.toContain("persona.indy");
    expect(selectPacks(model, root, ["persona.indy"])).toContain("persona.indy");
  });

  test("an unknown pack in the config is named, not silently dropped", async () => {
    const model = await RulesModel.load(ROOT);

    expect(() => selectPacks(model, scratch(), ["language.cobol"])).toThrow("unknown pack");
  });

  // Regression: install writes shell gate scripts. Counting them would select
  // the shell pack on the next install, which writes more shell — a set that
  // never settles. Files the lock records are excluded from the scan.
  test("files orly materialised are excluded, so selection settles", async () => {
    const model = await RulesModel.load(ROOT);
    const root = scratch();
    mkdirSync(join(root, "dispatch"), { recursive: true });
    writeFileSync(join(root, "dispatch/write_any.sh"), "#!/usr/bin/env bash\n");

    expect(selectPacks(model, root, [])).toContain(SHELL_PACK);
    expect(selectPacks(model, root, [], new Set(["dispatch/write_any.sh"]))).not.toContain(SHELL_PACK);
  });
});

describe("seedConfig", () => {
  test("maps Makefile targets onto gate commands, following one include level", async () => {
    const root = scratch();
    mkdirSync(join(root, "make"), { recursive: true });
    writeFileSync(join(root, "Makefile"), "include make/test.mk\nhelp:\n\t@echo help\n");
    writeFileSync(join(root, "make/test.mk"), "harness-verify:\n\t@true\ntest-unit-all:\n\t@true\n");

    const seed = await seedConfig(root);

    expect(seed.commands.conform).toEqual([["make", "harness-verify"]]);
    expect(seed.commands["verify.unit"]).toEqual([["make", "test-unit-all"]]);
  });

  test("maps package.json scripts when there is no Makefile", async () => {
    const root = scratch();
    writeFileSync(join(root, "package.json"), JSON.stringify({ scripts: { test: "vitest", build: "tsc" } }));

    const seed = await seedConfig(root);

    expect(seed.commands["verify.unit"]).toEqual([["bun", "run", "test"]]);
    expect(seed.commands["verify.build"]).toEqual([["bun", "run", "build"]]);
  });

  // A repository whose only quality target is `lint` matches both CONFORM and
  // verify.lint. Emitting both makes the gate run one command twice, in two
  // tiers, for one signal.
  test("a command that satisfies conform is not repeated as a verify tier", async () => {
    const root = scratch();
    writeFileSync(join(root, "package.json"), JSON.stringify({ scripts: { lint: "eslint ." } }));

    const seed = await seedConfig(root);

    expect(seed.commands.conform).toEqual([["bun", "run", "lint"]]);
    expect(seed.commands["verify.lint"]).toBeUndefined();
  });

  test("a Makefile target beats a package.json script of the same name", async () => {
    const root = scratch();
    writeFileSync(join(root, "Makefile"), "test:\n\t@true\n");
    writeFileSync(join(root, "package.json"), JSON.stringify({ scripts: { test: "vitest" } }));

    expect((await seedConfig(root)).commands["verify.unit"]).toEqual([["make", "test"]]);
  });

  test("a repository with no build files seeds no commands rather than wrong ones", async () => {
    expect((await seedConfig(scratch())).commands).toEqual({});
  });
});

describe("readConfig", () => {
  test("a malformed command is rejected by name", async () => {
    const root = scratch();
    writeConfigText(root, { schema_version: 1, packs: [], commands: { conform: "make audit" } });

    expect(readConfig(root)).rejects.toThrow("conform");
  });

  test("an unknown surface field is rejected", () => {
    const root = scratch();
    writeConfigText(root, { schema_version: 1, packs: [], commands: {}, surfaces: { sideways: ["src/"] } });

    expect(() => readConfigSync(root)).toThrow("sideways");
  });

  test("the sync and async readers agree", async () => {
    const root = scratch();
    writeConfigText(root, { schema_version: 1, packs: [], commands: { conform: [["make", "audit"]] }, surfaces: { user: ["src/"] } });

    expect(await readConfig(root)).toEqual(readConfigSync(root)!);
  });

  test("an absent config is undefined, not an error — the normal pre-init state", async () => {
    expect(await readConfig(scratch())).toBeUndefined();
  });
});

process.on("exit", () => {
  for (const path of temporary) rmSync(path, { recursive: true, force: true });
});
