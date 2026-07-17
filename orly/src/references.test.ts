import { describe, expect, test } from "bun:test";

import { renderProfileText } from "./references";

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
