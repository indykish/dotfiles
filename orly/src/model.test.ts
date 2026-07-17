import { describe, expect, test } from "bun:test";
import { resolve } from "node:path";

import { readJsonObject, RulesModel } from "./model";

const ROOT = resolve(import.meta.dir, "../..");

describe("RulesModel", () => {
  test("validates the current registry", async () => {
    const model = await RulesModel.load(ROOT);

    expect(() => model.validate()).not.toThrow();
  });

  test("rejects the declared invalid registry fixture", async () => {
    const registry = await readJsonObject(resolve(ROOT, "orly/fixtures/registry-invalid.json"));
    const model = new RulesModel(ROOT, registry, {}, { schema_version: 1, repositories: {} });

    expect(() => model.validate()).toThrow();
  });

  test("rejects missing mechanical rule fixtures", async () => {
    const source = await RulesModel.load(ROOT);
    const registry = structuredClone(source.registry);
    if (!Array.isArray(registry.rules) || typeof registry.rules[0] !== "object" || registry.rules[0] === null) throw new Error("mechanical rule missing");
    registry.rules[0] = { ...registry.rules[0], fixtures: { pass: ["orly/fixtures/missing.json"], fail: ["orly/fixtures/registry-invalid.json"] } };
    const model = new RulesModel(source.root, registry, source.profiles, source.repositories);

    expect(() => model.validate()).toThrow("fixture source is missing");
  });

  test("binds profile commands into only the selected profile digest", async () => {
    const source = await RulesModel.load(ROOT);
    const profiles = structuredClone(source.profiles);
    const agentsfleet = profiles.agentsfleet;
    if (!agentsfleet || typeof agentsfleet.commands !== "object" || agentsfleet.commands === null) throw new Error("agentsfleet commands missing");
    agentsfleet.commands = { ...agentsfleet.commands, conform: [["make", "other"]] };
    const changed = new RulesModel(source.root, source.registry, profiles, source.repositories);

    expect(await source.profileDigest("agentsfleet")).not.toBe(await changed.profileDigest("agentsfleet"));
    expect(await source.profileDigest("cache-kit")).toBe(await changed.profileDigest("cache-kit"));
  });
});
