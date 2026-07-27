import { describe, expect, test } from "bun:test";

import { isCode, isDocs, isUserSurface } from "./surfaces";

const USER_PREFIXES = ["src/agentsfleetd/http/", "public/openapi/", "cli/src/", "ui/packages/app/"];
const DOCS_PREFIXES = ["README.md", "docs/"];

describe("user surface", () => {
  test("handlers, openapi, cli, and app TypeScript count", () => {
    expect(isUserSurface("src/agentsfleetd/http/handlers/fleets.zig", USER_PREFIXES)).toBeTrue();
    expect(isUserSurface("public/openapi/paths/fleets.yaml", USER_PREFIXES)).toBeTrue();
    expect(isUserSurface("cli/src/commands/deploy.ts", USER_PREFIXES)).toBeTrue();
    expect(isUserSurface("ui/packages/app/pages/fleet.tsx", USER_PREFIXES)).toBeTrue();
  });

  test("tests, markdown, and other packages do not count", () => {
    expect(isUserSurface("src/agentsfleetd/http/handlers/fleets.test.zig", USER_PREFIXES)).toBeFalse();
    expect(isUserSurface("ui/packages/app/tests/fleet.spec.ts", USER_PREFIXES)).toBeFalse();
    expect(isUserSurface("public/openapi/AGENTS.md", USER_PREFIXES)).toBeFalse();
    expect(isUserSurface("ui/packages/website/pages/index.tsx", USER_PREFIXES)).toBeFalse();
    expect(isUserSurface("src/lib/pool.zig", USER_PREFIXES)).toBeFalse();
  });
});

describe("docs surface", () => {
  test("docs pages and README count; the spec tree never does", () => {
    expect(isDocs("docs/REST_API_DESIGN_GUIDELINES.md", DOCS_PREFIXES)).toBeTrue();
    expect(isDocs("README.md", DOCS_PREFIXES)).toBeTrue();
    expect(isDocs("docs/v1/active/M01_001_P2_CLI_DOCS_PROCESS_AS_CODE.md", DOCS_PREFIXES)).toBeFalse();
    expect(isDocs("docs/v2/pending/M52_001_P2_API_X.md", DOCS_PREFIXES)).toBeFalse();
    expect(isDocs("src/agentsfleetd/main.zig", DOCS_PREFIXES)).toBeFalse();
  });
});

describe("code classification", () => {
  test("source and test files are code; prose is not", () => {
    expect(isCode("orly/src/lifecycle.ts")).toBeTrue();
    expect(isCode("src/agentsfleetd/tests.zig")).toBeTrue();
    expect(isCode("ui/packages/app/tests/fleet.spec.ts")).toBeTrue();
    expect(isCode("docs/VERIFY_TIERS.md")).toBeFalse();
    expect(isCode("SOUL.md")).toBeFalse();
  });
});
