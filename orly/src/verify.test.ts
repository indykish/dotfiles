import { expect, test } from "bun:test";
import { resolve } from "node:path";

import { RulesModel } from "./model";
import { verifyRenders } from "./verify";

const ROOT = resolve(import.meta.dir, "../..");

test("every profile renders deterministically", async () => {
  const checks = await verifyRenders(await RulesModel.load(ROOT));

  expect(checks.filter((check) => check.name.endsWith(".idempotent")).every((check) => check.result === "pass")).toBeTrue();
});
