import { expect, test } from "bun:test";

import { validateRelativePath } from "./validation";

test("relative paths cannot escape the output root", () => {
  const errors: string[] = [];

  validateRelativePath("../outside.md", "fixture", errors);

  expect(errors).toEqual(["fixture must stay below the output root: ../outside.md"]);
});
