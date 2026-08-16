import { afterEach, describe, expect, test } from "bun:test";
import { chmodSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { applyMode, buildLock, hashContent, lockDrift, lockPath, modeLabel, readLock, staleVersion, writeLock } from "./lockfile";

const temporaryDirectories: string[] = [];
afterEach(() => {
  for (const path of temporaryDirectories.splice(0)) rmSync(path, { recursive: true, force: true });
});

describe("hashContent", () => {
  test("identical content hashes identically", () => {
    expect(hashContent("same text")).toBe(hashContent("same text"));
  });

  test("a single changed byte changes the hash", () => {
    expect(hashContent("same text")).not.toBe(hashContent("same texu"));
  });

  test("empty content hashes deterministically, not to an empty string", () => {
    const hash = hashContent("");
    expect(hash.length).toBeGreaterThan(0);
    expect(hash).toBe(hashContent(""));
  });

  test("bytes and the equivalent string hash identically", () => {
    const text = "unicode: 日本語 🦉";
    expect(hashContent(text)).toBe(hashContent(new TextEncoder().encode(text)));
  });
});

describe("modeLabel / applyMode", () => {
  test("an executable file round-trips as 0755", async () => {
    const path = await writeFixture("script.sh", "#!/bin/sh\n");
    applyMode(path, "0755");
    expect(modeLabel(path)).toBe("0755");
  });

  test("a non-executable file round-trips as 0644", async () => {
    const path = await writeFixture("notes.md", "# notes\n");
    applyMode(path, "0644");
    expect(modeLabel(path)).toBe("0644");
  });

  test("applyMode flips a file from 0644 to 0755", async () => {
    const path = await writeFixture("flip.sh", "echo hi\n");
    applyMode(path, "0644");
    expect(modeLabel(path)).toBe("0644");
    applyMode(path, "0755");
    expect(modeLabel(path)).toBe("0755");
  });
});

describe("buildLock", () => {
  test("sorts packs and file entries regardless of insertion order", () => {
    const lock = buildLock("0.4.0", ["language.shell", "domain.documentation"], {
      "dispatch/write_shell.md": { sha256: "b", mode: "0644" },
      "AGENTS.md": { sha256: "a", mode: "0644" },
    });
    expect(lock.packs).toEqual(["domain.documentation", "language.shell"]);
    expect(Object.keys(lock.files)).toEqual(["AGENTS.md", "dispatch/write_shell.md"]);
  });

  test("carries the schema version and the given packs/version verbatim", () => {
    const lock = buildLock("1.2.3", ["language.rust"], {});
    expect(lock.schema_version).toBe(2);
    expect(lock.orly_version).toBe("1.2.3");
    expect(lock.packs).toEqual(["language.rust"]);
  });
});

describe("readLock / writeLock", () => {
  test("a repository with no lock reads as undefined, not an error", async () => {
    const root = temporaryDirectory();
    expect(await readLock(root)).toBeUndefined();
  });

  test("writeLock then readLock round-trips the same shape", async () => {
    const root = temporaryDirectory();
    const lock = buildLock("0.4.0", ["language.rust"], { "dispatch/write_rust.md": { sha256: "abc", mode: "0644" } });
    await writeLock(root, lock);
    expect(await readLock(root)).toEqual(lock);
  });

  test("writeLock creates the .oracle/ parent directory", async () => {
    const root = temporaryDirectory();
    await writeLock(root, buildLock("0.4.0", [], {}));
    expect(Bun.file(lockPath(root)).size).toBeGreaterThan(0);
  });

  test("a lock with the wrong schema_version throws, naming the expected version", async () => {
    const root = temporaryDirectory();
    await Bun.write(lockPath(root), JSON.stringify({ schema_version: 3, orly_version: "0.4.0", packs: [], files: {} }));
    expect(readLock(root)).rejects.toThrow("schema_version must equal 2");
  });

  test("a lock missing orly_version throws rather than silently defaulting", async () => {
    const root = temporaryDirectory();
    await Bun.write(lockPath(root), JSON.stringify({ schema_version: 2, packs: [], files: {} }));
    expect(readLock(root)).rejects.toThrow("an orly_version string");
  });

  test("a file entry missing sha256 throws, naming the offending path", async () => {
    const root = temporaryDirectory();
    await Bun.write(lockPath(root), JSON.stringify({ schema_version: 2, orly_version: "0.4.0", packs: [], files: { "AGENTS.md": { mode: "0644" } } }));
    expect(readLock(root)).rejects.toThrow("AGENTS.md");
  });
});

describe("lockDrift", () => {
  test("a repository whose files match the lock reports no drift", async () => {
    const root = temporaryDirectory();
    const path = await writeFixture("AGENTS.md", "rules\n", root);
    const lock = buildLock("0.4.0", [], { "AGENTS.md": { sha256: hashContent(await Bun.file(path).bytes()), mode: modeLabel(path) } });
    expect(await lockDrift(root, lock)).toEqual([]);
  });

  test("editing a managed file in place is reported by name, with a recovery command", async () => {
    const root = temporaryDirectory();
    const path = await writeFixture("AGENTS.md", "rules\n", root);
    const original = hashContent(await Bun.file(path).bytes());
    await Bun.write(path, "rules\nedited by hand\n");
    const lock = buildLock("0.4.0", [], { "AGENTS.md": { sha256: original, mode: modeLabel(path) } });
    const findings = await lockDrift(root, lock);
    expect(findings).toHaveLength(1);
    expect(findings[0]).toContain("AGENTS.md");
    expect(findings[0]).toContain("orly init --force");
  });

  test("a deleted managed file is reported as missing, not silently dropped", async () => {
    const root = temporaryDirectory();
    const lock = buildLock("0.4.0", [], { "dispatch/write_rust.md": { sha256: "does-not-matter", mode: "0644" } });
    const findings = await lockDrift(root, lock);
    expect(findings).toHaveLength(1);
    expect(findings[0]).toContain("dispatch/write_rust.md");
    expect(findings[0]).toContain("missing");
  });

  test("a mode change alone (content untouched) is reported distinctly from a content edit", async () => {
    const root = temporaryDirectory();
    const path = await writeFixture("hook.sh", "#!/bin/sh\n", root);
    applyMode(path, "0755");
    const lock = buildLock("0.4.0", [], { "hook.sh": { sha256: hashContent(await Bun.file(path).bytes()), mode: "0755" } });
    applyMode(path, "0644");
    const findings = await lockDrift(root, lock);
    expect(findings).toHaveLength(1);
    expect(findings[0]).toContain("mode changed");
  });

  test("findings are sorted, so output is stable across runs", async () => {
    const root = temporaryDirectory();
    const lock = buildLock("0.4.0", [], {
      "zzz.md": { sha256: "x", mode: "0644" },
      "aaa.md": { sha256: "y", mode: "0644" },
    });
    const findings = await lockDrift(root, lock);
    expect(findings[0]).toContain("aaa.md");
    expect(findings[1]).toContain("zzz.md");
  });
});

describe("staleVersion", () => {
  test("a lock pinned to the installed version reports no staleness", () => {
    const lock = buildLock("0.4.0", [], {});
    expect(staleVersion(lock, "0.4.0")).toBeUndefined();
  });

  test("an older pin names both versions and the fix command", () => {
    const lock = buildLock("0.3.0", [], {});
    const message = staleVersion(lock, "0.4.0");
    expect(message).toContain("0.3.0");
    expect(message).toContain("0.4.0");
    expect(message).toContain("orly update");
  });
});

function temporaryDirectory(): string {
  const path = mkdtempSync(join(tmpdir(), "orly-lockfile-test-"));
  temporaryDirectories.push(path);
  return path;
}

async function writeFixture(name: string, content: string, root?: string): Promise<string> {
  const base = root ?? temporaryDirectory();
  const path = join(base, name);
  await Bun.write(path, content);
  chmodSync(path, 0o644);
  return path;
}
