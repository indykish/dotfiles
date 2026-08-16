import { afterEach, describe, expect, test } from "bun:test";
import { existsSync, mkdirSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { cleanupTemporaryDirectories, git, gitOutput, newRepository, ROOT } from "./gates_test_support";
import { install } from "./install";
import { readLock } from "./lockfile";
import { RulesModel } from "./model";

afterEach(cleanupTemporaryDirectories);

const KERNEL = "kernel";
const CACHE_KIT = "cache-kit";

describe("install", () => {
  test("materialises the selected profile's packs, hooks, and a lock into a fresh repository", async () => {
    const model = await RulesModel.load(ROOT);
    const repo = newRepository();

    const result = await install(model, { targetRoot: repo, profile: CACHE_KIT, force: false, installHooks: true, orlyVersion: "0.4.0" });

    expect(result.ok).toBe(true);
    expect(result.profile).toBe(CACHE_KIT);
    expect(existsSync(join(repo, "AGENTS.md"))).toBe(true);
    expect(existsSync(join(repo, "dispatch/write_rust.md"))).toBe(true);
    expect(existsSync(join(repo, ".githooks/pre-commit"))).toBe(true);
    expect(existsSync(join(repo, ".oracle/ruleset.lock"))).toBe(true);
  });

  test("a second install over the same target reports zero writes", async () => {
    const model = await RulesModel.load(ROOT);
    const repo = newRepository();
    await install(model, { targetRoot: repo, profile: KERNEL, force: false, installHooks: true, orlyVersion: "0.4.0" });

    const second = await install(model, { targetRoot: repo, profile: KERNEL, force: false, installHooks: true, orlyVersion: "0.4.0" });

    expect(second.ok).toBe(true);
    expect(second.written).toEqual([]);
    expect(second.skipped.length).toBeGreaterThan(0);
  });

  test("refuses to overwrite a hand-edited managed file without --force, naming the offending path", async () => {
    const model = await RulesModel.load(ROOT);
    const repo = newRepository();
    await install(model, { targetRoot: repo, profile: CACHE_KIT, force: false, installHooks: true, orlyVersion: "0.4.0" });
    await Bun.write(join(repo, "dispatch/write_rust.md"), "hand-edited\n");

    const result = await install(model, { targetRoot: repo, profile: CACHE_KIT, force: false, installHooks: true, orlyVersion: "0.4.0" });

    expect(result.ok).toBe(false);
    expect(result.errors).toHaveLength(1);
    expect(result.errors[0]?.path).toBe("dispatch/write_rust.md");
    expect(result.errors[0]?.message).toContain("edited in place");
    expect(await Bun.file(join(repo, "dispatch/write_rust.md")).text()).toBe("hand-edited\n");
  });

  test("--force overwrites a hand-edited managed file", async () => {
    const model = await RulesModel.load(ROOT);
    const repo = newRepository();
    await install(model, { targetRoot: repo, profile: CACHE_KIT, force: false, installHooks: true, orlyVersion: "0.4.0" });
    await Bun.write(join(repo, "dispatch/write_rust.md"), "hand-edited\n");

    const result = await install(model, { targetRoot: repo, profile: CACHE_KIT, force: true, installHooks: true, orlyVersion: "0.4.0" });

    expect(result.ok).toBe(true);
    expect(await Bun.file(join(repo, "dispatch/write_rust.md")).text()).not.toBe("hand-edited\n");
  });

  test("rejects a target that is not a git repository, naming the fix", async () => {
    const model = await RulesModel.load(ROOT);
    const notARepo = mkdtempSync(join(tmpdir(), "orly-install-not-a-repo-"));
    try {
      expect(install(model, { targetRoot: notARepo, profile: KERNEL, force: false, installHooks: true, orlyVersion: "0.4.0" })).rejects.toThrow("git init");
    } finally {
      rmSync(notARepo, { recursive: true, force: true });
    }
  });

  test("rejects a target directory that does not exist at all", async () => {
    const model = await RulesModel.load(ROOT);
    expect(install(model, { targetRoot: join(tmpdir(), "orly-install-never-created"), profile: KERNEL, force: false, installHooks: true, orlyVersion: "0.4.0" })).rejects.toThrow("does not exist");
  });

  test("rejects an unknown profile before writing anything", async () => {
    const model = await RulesModel.load(ROOT);
    const repo = newRepository();

    expect(install(model, { targetRoot: repo, profile: "not-a-real-profile", force: false, installHooks: true, orlyVersion: "0.4.0" })).rejects.toThrow("unknown profile");
    expect(existsSync(join(repo, "AGENTS.md"))).toBe(false);
  });

  test("sets core.hooksPath and installs both hooks with the git-scope-unsetting preamble", async () => {
    const model = await RulesModel.load(ROOT);
    const repo = newRepository();

    await install(model, { targetRoot: repo, profile: KERNEL, force: false, installHooks: true, orlyVersion: "0.4.0" });

    expect(gitOutput(repo, "config", "--get", "core.hooksPath")).toBe(".githooks");
    for (const hook of ["pre-commit", "pre-push"]) {
      const text = await Bun.file(join(repo, ".githooks", hook)).text();
      expect(text).toContain("GIT_DIR");
    }
  });

  test("--no-hooks skips hook installation and leaves core.hooksPath unset", async () => {
    const model = await RulesModel.load(ROOT);
    const repo = newRepository();

    await install(model, { targetRoot: repo, profile: KERNEL, force: false, installHooks: false, orlyVersion: "0.4.0" });

    expect(existsSync(join(repo, ".githooks"))).toBe(false);
    expect(gitOutput(repo, "config", "--get", "core.hooksPath")).toBe("");
  });

  test("refuses to retarget a hooksPath already claimed by something else", async () => {
    const model = await RulesModel.load(ROOT);
    const repo = newRepository();
    git(repo, "config", "core.hooksPath", "some-other-tools-hooks");

    const result = await install(model, { targetRoot: repo, profile: KERNEL, force: false, installHooks: true, orlyVersion: "0.4.0" });

    expect(result.ok).toBe(false);
    expect(result.errors.some((error) => error.path === "core.hooksPath")).toBe(true);
    expect(gitOutput(repo, "config", "--get", "core.hooksPath")).toBe("some-other-tools-hooks");
    expect(existsSync(join(repo, "AGENTS.md"))).toBe(false);
  });

  test("--no-hooks proceeds even when hooksPath is claimed by something else", async () => {
    const model = await RulesModel.load(ROOT);
    const repo = newRepository();
    git(repo, "config", "core.hooksPath", "some-other-tools-hooks");

    const result = await install(model, { targetRoot: repo, profile: KERNEL, force: false, installHooks: false, orlyVersion: "0.4.0" });

    expect(result.ok).toBe(true);
    expect(gitOutput(repo, "config", "--get", "core.hooksPath")).toBe("some-other-tools-hooks");
  });

  test("--force retargets a hooksPath claimed by something else", async () => {
    const model = await RulesModel.load(ROOT);
    const repo = newRepository();
    git(repo, "config", "core.hooksPath", "some-other-tools-hooks");

    const result = await install(model, { targetRoot: repo, profile: KERNEL, force: true, installHooks: true, orlyVersion: "0.4.0" });

    expect(result.ok).toBe(true);
    expect(gitOutput(repo, "config", "--get", "core.hooksPath")).toBe(".githooks");
  });

  test("re-running init after it already set hooksPath is not a claim by another tool", async () => {
    const model = await RulesModel.load(ROOT);
    const repo = newRepository();
    await install(model, { targetRoot: repo, profile: KERNEL, force: false, installHooks: true, orlyVersion: "0.4.0" });

    const second = await install(model, { targetRoot: repo, profile: KERNEL, force: false, installHooks: true, orlyVersion: "0.4.0" });

    expect(second.ok).toBe(true);
  });

  test("the written lock records a hash and mode for every materialised file", async () => {
    const model = await RulesModel.load(ROOT);
    const repo = newRepository();

    await install(model, { targetRoot: repo, profile: CACHE_KIT, force: false, installHooks: true, orlyVersion: "0.4.0" });

    const lock = await readLock(repo);
    expect(lock).toBeDefined();
    expect(lock?.profile).toBe(CACHE_KIT);
    expect(lock?.files["dispatch/write_rust.md"]?.sha256.length).toBeGreaterThan(0);
    expect(lock?.files["dispatch/write_rust.md"]?.mode).toBe("0644");
  });

  test("refuses atomically when a selected pack's file cites a façade no selected pack provides", async () => {
    // The §4 registry defects (dispatch/lifecycle.md owned by no pack;
    // dispatch/name_architecture.md behind a pack universal prose didn't
    // select) were exactly this shape: a synthetic engine root with one pack
    // whose only managed file cites a dispatch/ path nothing installs.
    const engineRoot = mkdtempSync(join(tmpdir(), "orly-install-broken-engine-"));
    try {
      mkdirSync(join(engineRoot, "orly"), { recursive: true });
      await Bun.write(join(engineRoot, "orly/core.md"), "core\n");
      await Bun.write(join(engineRoot, "broken.md"), "cites dispatch/missing.md\n");

      const registry = {
        schema_version: 1,
        core_documents: ["orly/core.md"],
        packs: { broken: { extensions: [], managed_files: [{ source: "broken.md", target: "broken.md" }] } },
        rules: [],
      };
      const profiles = { broken: { schema_version: 1, name: "broken", packs: ["broken"], commands: { conform: [["true"]] } } };
      const repositories = { schema_version: 1, repositories: {} };
      const model = new RulesModel(engineRoot, registry, profiles, repositories);
      const repo = newRepository();

      const result = await install(model, { targetRoot: repo, profile: "broken", force: false, installHooks: true, orlyVersion: "0.4.0" });

      expect(result.ok).toBe(false);
      expect(result.errors[0]?.message).toContain("missing dispatch reference");
      expect(existsSync(join(repo, "broken.md"))).toBe(false);
      expect(existsSync(join(repo, "AGENTS.md"))).toBe(false);
      expect(existsSync(join(repo, ".oracle"))).toBe(false);
    } finally {
      rmSync(engineRoot, { recursive: true, force: true });
    }
  });

  test("two packs disagreeing on one target's source is a registry error, not a silent pick", async () => {
    const engineRoot = mkdtempSync(join(tmpdir(), "orly-install-conflict-engine-"));
    try {
      mkdirSync(join(engineRoot, "orly"), { recursive: true });
      await Bun.write(join(engineRoot, "orly/core.md"), "core\n");
      await Bun.write(join(engineRoot, "a.md"), "from pack a\n");
      await Bun.write(join(engineRoot, "b.md"), "from pack b\n");

      const registry = {
        schema_version: 1,
        core_documents: ["orly/core.md"],
        packs: {
          a: { extensions: [], managed_files: [{ source: "a.md", target: "shared.md" }] },
          b: { extensions: [], managed_files: [{ source: "b.md", target: "shared.md" }] },
        },
        rules: [],
      };
      const profiles = { conflict: { schema_version: 1, name: "conflict", packs: ["a", "b"], commands: { conform: [["true"]] } } };
      const repositories = { schema_version: 1, repositories: {} };
      const model = new RulesModel(engineRoot, registry, profiles, repositories);
      const repo = newRepository();

      expect(install(model, { targetRoot: repo, profile: "conflict", force: false, installHooks: true, orlyVersion: "0.4.0" })).rejects.toThrow("packs disagree on shared.md");
    } finally {
      rmSync(engineRoot, { recursive: true, force: true });
    }
  });
});
