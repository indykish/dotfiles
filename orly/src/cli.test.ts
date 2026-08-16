import { describe, expect, test } from "bun:test";
import { resolve } from "node:path";

const ROOT = resolve(import.meta.dir, "../..");
const COMMAND = resolve(ROOT, "bin/orly");

describe("orly command", () => {
  test("uses the concise public command surface", () => {
    const result = Bun.spawnSync([COMMAND, "--help"], { cwd: ROOT, stdout: "pipe", stderr: "pipe" });
    const output = result.stdout.toString();

    expect(result.exitCode).toBe(0);
    expect(output).toContain("orly gate");
    expect(output).toContain("orly override <CRITERION> --reason <REASON>");
    expect(output).not.toContain("orly adopt");
    expect(output).not.toContain("oracle-rules");
  });

  test("reports the version carried by the package manifest", async () => {
    const result = Bun.spawnSync([COMMAND, "--version"], { cwd: ROOT, stdout: "pipe", stderr: "pipe" });
    const manifest = (await Bun.file(resolve(ROOT, "package.json")).json()) as { version: string };

    expect(result.exitCode).toBe(0);
    expect(result.stdout.toString().trim()).toBe(manifest.version);
  });

  test("validates the registry", () => {
    const result = Bun.spawnSync([COMMAND, "validate"], { cwd: ROOT, stdout: "pipe", stderr: "pipe" });

    expect(result.exitCode).toBe(0);
    expect(result.stdout.toString().trim()).toBe("orly: registry and profiles valid");
  });
});
