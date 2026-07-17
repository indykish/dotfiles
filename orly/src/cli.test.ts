import { describe, expect, test } from "bun:test";
import { resolve } from "node:path";

const ROOT = resolve(import.meta.dir, "../..");
const COMMAND = resolve(ROOT, "bin/orly");

describe("orly command", () => {
  test("uses the concise public command surface", () => {
    const result = Bun.spawnSync([COMMAND, "--help"], { cwd: ROOT, stdout: "pipe", stderr: "pipe" });
    const output = result.stdout.toString();

    expect(result.exitCode).toBe(0);
    expect(output).toContain("orly adopt <REPOSITORY>");
    expect(output).toContain("orly sync <REPOSITORY|--all|--global>");
    expect(output).not.toContain("oracle-rules");
  });

  test("validates the registry", () => {
    const result = Bun.spawnSync([COMMAND, "validate"], { cwd: ROOT, stdout: "pipe", stderr: "pipe" });

    expect(result.exitCode).toBe(0);
    expect(result.stdout.toString().trim()).toBe("orly: registry and profiles valid");
  });
});
