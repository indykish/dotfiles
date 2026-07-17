from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from oracle_rules.model import RulesModel, RulesValidationError, load_json
from oracle_rules.render import Renderer


ROOT = Path(__file__).resolve().parents[2]


class RendererTests(unittest.TestCase):
    def setUp(self) -> None:
        self.model = RulesModel.load(ROOT)
        self.model.validate()
        self.renderer = Renderer(self.model)

    def test_render_is_byte_stable(self) -> None:
        with tempfile.TemporaryDirectory() as first_dir:
            with tempfile.TemporaryDirectory() as second_dir:
                first_hashes = self.renderer.render("agentsfleet", Path(first_dir))
                second_hashes = self.renderer.render("agentsfleet", Path(second_dir))

        self.assertEqual(first_hashes, second_hashes)

    def test_agents_file_contains_lifecycle_and_profile_command(self) -> None:
        with tempfile.TemporaryDirectory() as output_dir:
            output_root = Path(output_dir)
            self.renderer.render("agentsfleet", output_root)
            agents = (output_root / "AGENTS.md").read_text(encoding="utf-8")

        self.assertIn("EXECUTE → CONFORM → VERIFY → REVIEW", agents)
        self.assertIn("`make harness-verify`", agents)

    def test_agentsfleet_dispatch_paths_match_the_operating_model(self) -> None:
        with tempfile.TemporaryDirectory() as output_dir:
            output_root = Path(output_dir)
            self.renderer.render("agentsfleet", output_root)

            self.assertTrue(
                (output_root / "dispatch/write_ts_adhere_bun.md").is_file()
            )
            self.assertFalse((output_root / "dispatch/write_typescript.md").exists())

    def test_agentsfleet_snapshot_contains_repository_rule_dependencies(self) -> None:
        expected_paths = {
            "audits/agents-md.md",
            "audits/cross-tier-rates.sh",
            "audits/design-tokens.sh",
            "audits/error-codes.sh",
            "audits/spec-template.sh",
            "dispatch/edit_rules.md",
            "dispatch/write_python.md",
            "docs/EXECUTE_DOC_READS.md",
            "docs/HARNESS_VERIFY_OUTPUT.md",
            "docs/LIFECYCLE_PATTERNS.md",
            "docs/LOGGING_STANDARD.md",
            "docs/VERIFY_TIERS.md",
            "docs/greptile-learnings/RULES.md",
        }
        with tempfile.TemporaryDirectory() as output_dir:
            output_root = Path(output_dir)
            self.renderer.render("agentsfleet", output_root)
            managed = load_json(output_root / ".oracle/managed-files.json")

        self.assertTrue(expected_paths <= set(managed["files"]))

    def test_tampered_managed_file_fails_lock_verification(self) -> None:
        with tempfile.TemporaryDirectory() as output_dir:
            output_root = Path(output_dir)
            self.renderer.render("global", output_root)
            (output_root / "AGENTS.md").write_text("tampered\n", encoding="utf-8")

            errors = self.renderer.verify_lock(output_root)

        self.assertIn("managed file changed: AGENTS.md", errors)

    def test_declared_tampered_lock_fixture_fails_verification(self) -> None:
        with tempfile.TemporaryDirectory() as output_dir:
            output_root = Path(output_dir)
            self.renderer.render("global", output_root)
            fixture = load_json(
                ROOT / "oracle-rules/tests/fixtures/tampered-lock.json"
            )
            lock_path = output_root / ".oracle/ruleset.lock"
            lock_path.write_text(
                json.dumps(fixture) + "\n", encoding="utf-8"
            )

            errors = self.renderer.verify_lock(output_root)

        self.assertTrue(errors)

    def test_invalid_lock_json_reports_validation_error(self) -> None:
        with tempfile.TemporaryDirectory() as output_dir:
            output_root = Path(output_dir)
            self.renderer.render("global", output_root)
            (output_root / ".oracle/ruleset.lock").write_text(
                "not json\n", encoding="utf-8"
            )

            with self.assertRaisesRegex(
                RulesValidationError, "cannot read JSON object"
            ):
                self.renderer.verify_lock(output_root)


if __name__ == "__main__":
    unittest.main()
