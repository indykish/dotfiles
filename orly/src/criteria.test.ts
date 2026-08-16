import { afterEach, describe, expect, test } from "bun:test";

import { criteriaFor, repositoryFor, runCommand } from "./criteria";
import { cleanupTemporaryDirectories, modelFor, newRepository, newSpecRepository } from "./gates_test_support";

const WORK = "work";
const VERIFY = "verify";
const PR = "pr";
const REPO_PROFILE = "repo.profile";

afterEach(cleanupTemporaryDirectories);

// criteriaFor is the composition point: gates.ts asks it what a named gate
// evaluates, so a criterion silently dropped from a group would be invisible
// to every other suite. These pin the membership of each group by name.
describe("criteriaFor", () => {
  async function contextFor(root: string) {
    return { root, model: await modelFor(root), acceptDirty: false };
  }

  function named(gate: string, context: Awaited<ReturnType<typeof contextFor>>): string[] {
    return criteriaFor(gate, context).map((criterion) => criterion.name).sort();
  }

  test("work evaluates the branch, the tree and the profile", async () => {
    const project = newSpecRepository();
    expect(named(WORK, await contextFor(project))).toEqual(["git.branch", "git.tree", REPO_PROFILE]);
  });

  test("verify pairs the spec dimensions with the fast command tier only", async () => {
    const project = newSpecRepository();
    const names = named(VERIFY, await contextFor(project));

    expect(names).toContain("spec.dimensions");
    expect(names).toContain("cmd.conform");
    // The slow tier belongs to the pr gate; leaking it here would make every
    // verify run pay for integration and memory suites.
    expect(names).not.toContain("cmd.verify.integration");
  });

  test("pr carries every closed-spec follow-through criterion", async () => {
    const project = newSpecRepository();
    const names = named(PR, await contextFor(project));

    for (const required of ["spec.moved", "spec.baseline", "spec.ordering", "spec.deferrals", "docs.updated"]) {
      expect(names).toContain(required);
    }
    // git.branch is a work-gate concern: by pr time the branch is established,
    // and re-asserting it would make an already-merged branch un-gateable.
    expect(names).not.toContain("git.branch");
  });

  test("an unknown gate name yields no criteria rather than throwing", async () => {
    const project = newSpecRepository();
    expect(criteriaFor("nonsense", await contextFor(project))).toEqual([]);
  });

  test("an unregistered repository still yields a red profile criterion on verify", async () => {
    const stranger = newRepository();
    const context = { root: stranger, model: await modelFor(newSpecRepository()), acceptDirty: false };

    const results = criteriaFor(VERIFY, context).map((criterion) => criterion.evaluate(context));
    const profile = results.find((result) => result.name === REPO_PROFILE);
    expect(profile?.ok).toBeFalse();
    expect(profile?.detail).toContain("not registered");
  });
});

describe("runCommand", () => {
  test("a zero exit reports ok with the exit-0 detail", () => {
    expect(runCommand(process.cwd(), ["true"])).toEqual({ ok: true, detail: "exit 0" });
  });

  test("a non-zero exit carries the code and the last output line", () => {
    const result = runCommand(process.cwd(), ["sh", "-c", "echo first; echo decisive >&2; exit 3"]);

    expect(result.ok).toBeFalse();
    expect(result.detail).toContain("exit 3");
    expect(result.detail).toEndWith("decisive");
  });

  test("a silent failure still reports a detail rather than an empty string", () => {
    const result = runCommand(process.cwd(), ["false"]);

    expect(result.ok).toBeFalse();
    expect(result.detail).toBe("exit 1: no output");
  });

  test("a missing binary is a failure, never a throw", () => {
    expect(runCommand(process.cwd(), ["orly-no-such-binary"]).ok).toBeFalse();
  });
});

describe("repositoryFor", () => {
  test("resolves a registered checkout to its registry name", async () => {
    const project = newSpecRepository();
    expect(repositoryFor(await modelFor(project), project)).toBe("fixture");
  });

  test("an unrelated checkout resolves to undefined", async () => {
    const model = await modelFor(newSpecRepository());
    expect(repositoryFor(model, newRepository())).toBeUndefined();
  });
});
