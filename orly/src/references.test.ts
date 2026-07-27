import { describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { referenceClosureErrors, renderProfileText } from "./references";

describe("renderProfileText", () => {
  test("keeps selected pack lines and removes their marker", () => {
    const content = "before\nselected <!-- oracle-packs:language.rust -->\nremoved <!-- oracle-packs:language.zig -->\nafter";

    const rendered = renderProfileText(
      content,
      new Set(["language.rust"]),
      new Set(["language.rust", "language.zig"]),
      "fixture.md",
    );

    expect(rendered).toBe("before\nselected\nafter");
  });

  test("rejects unknown pack markers", () => {
    expect(() => renderProfileText(
      "before\n<!-- oracle-packs:language.unknown -->\nafter",
      new Set(["language.rust"]),
      new Set(["language.rust"]),
      "fixture.md",
    )).toThrow("unknown orly pack marker");
  });
});

describe("referenceClosureErrors", () => {
  test("flags missing dispatch references in every rendered Markdown file", async () => {
    const output = mkdtempSync(join(tmpdir(), "orly-references-test-"));
    try {
      mkdirSync(join(output, "docs"));
      const documentPath = join(output, "docs/EXECUTE_DOC_READS.md");
      await Bun.write(documentPath, "| `*.rs` | `dispatch/write_rust.md` |\n");

      const errors = await referenceClosureErrors(output, [documentPath]);

      expect(errors).toContain("missing dispatch reference: docs/EXECUTE_DOC_READS.md:1 -> dispatch/write_rust.md");
    } finally {
      rmSync(output, { recursive: true, force: true });
    }
  });
});
