from __future__ import annotations

import copy
import subprocess
import tempfile
import unittest
from pathlib import Path

from oracle_rules.model import RulesModel, RulesValidationError
from oracle_rules.render import Renderer
from oracle_rules.repository import (
    doctor_agent_homes,
    doctor_repository,
    link_agent_homes,
    sync_repository,
)


ROOT = Path(__file__).resolve().parents[2]


class RepositoryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.project_root = Path(self.temp_dir.name)
        self._git("init")
        self._git("config", "user.email", "oracle-tests@example.invalid")
        self._git("config", "user.name", "Oracle Tests")
        (self.project_root / "AGENTS.project.md").write_text(
            "# Test repository\n", encoding="utf-8"
        )
        self._git("add", "AGENTS.project.md")
        self._git("commit", "-m", "test: initialize repository")

        source_model = RulesModel.load(ROOT)
        repositories = copy.deepcopy(source_model.repositories)
        repositories["repositories"]["test"] = {
            "path": str(self.project_root),
            "profile": "global",
        }
        self.model = RulesModel(
            root=source_model.root,
            registry=source_model.registry,
            profiles=source_model.profiles,
            repositories=repositories,
        )

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def test_sync_writes_real_tracked_snapshot_candidates(self) -> None:
        copied = sync_repository(self.model, "test")

        self.assertIn("AGENTS.md", copied)
        self.assertTrue((self.project_root / "AGENTS.md").is_file())
        self.assertFalse((self.project_root / "AGENTS.md").is_symlink())
        self.assertEqual(doctor_repository(self.model, "test"), [])

    def test_sync_refuses_dirty_repository(self) -> None:
        (self.project_root / "unexpected.txt").write_text("dirty\n", encoding="utf-8")

        with self.assertRaisesRegex(RulesValidationError, "must be clean"):
            sync_repository(self.model, "test")

    def test_sync_refuses_unmanaged_existing_file(self) -> None:
        agents_path = self.project_root / "AGENTS.md"
        agents_path.write_text("local instructions\n", encoding="utf-8")
        self._git("add", "AGENTS.md")
        self._git("commit", "-m", "test: add local instructions")

        with self.assertRaisesRegex(RulesValidationError, "unmanaged path"):
            sync_repository(self.model, "test")

    def test_sync_accepts_dotfiles_owned_legacy_symlink(self) -> None:
        agents_path = self.project_root / "AGENTS.md"
        agents_path.symlink_to(ROOT / "AGENTS.md")
        self._git("add", "AGENTS.md")
        self._git("commit", "-m", "test: add legacy instructions link")

        sync_repository(self.model, "test")

        self.assertTrue(agents_path.is_file())
        self.assertFalse(agents_path.is_symlink())

    def test_doctor_reports_registry_drift(self) -> None:
        sync_repository(self.model, "test")
        (self.project_root / "AGENTS.md").write_text("changed\n", encoding="utf-8")

        errors = doctor_repository(self.model, "test")

        self.assertIn("managed file changed: AGENTS.md", errors)

    def test_doctor_reports_profile_mismatch(self) -> None:
        sync_repository(self.model, "test")
        lock_path = self.project_root / ".oracle/ruleset.lock"
        lock = lock_path.read_text(encoding="utf-8").replace(
            '"profile": "global"', '"profile": "agentsfleet"'
        )
        lock_path.write_text(lock, encoding="utf-8")

        errors = doctor_repository(self.model, "test")

        self.assertIn("ruleset profile is agentsfleet, expected global", errors)

    def test_agent_home_retargets_dotfiles_owned_symlink(self) -> None:
        generated_root = self.project_root / "generated/global"
        Renderer(self.model).render("global", generated_root)
        agent_home = self.project_root / "agent-home"
        target = agent_home / ".codex/AGENTS.md"
        target.parent.mkdir(parents=True)
        target.symlink_to(ROOT / "AGENTS.md")

        linked = link_agent_homes(
            self.model, agent_home, generated_root / "AGENTS.md"
        )

        self.assertEqual(linked, [str(target)])
        self.assertEqual(target.resolve(), (generated_root / "AGENTS.md").resolve())
        self.assertEqual(
            doctor_agent_homes(
                self.model, agent_home, generated_root / "AGENTS.md"
            ),
            [],
        )

    def test_agent_home_refuses_external_symlink(self) -> None:
        generated_root = self.project_root / "generated/global"
        Renderer(self.model).render("global", generated_root)
        agent_home = self.project_root / "agent-home"
        target = agent_home / ".codex/AGENTS.md"
        target.parent.mkdir(parents=True)
        external = self.project_root / "external.md"
        external.write_text("external\n", encoding="utf-8")
        target.symlink_to(external)

        with self.assertRaisesRegex(RulesValidationError, "refusing to replace"):
            link_agent_homes(
                self.model, agent_home, generated_root / "AGENTS.md"
            )

    def test_agent_home_refuses_stale_generated_rules(self) -> None:
        generated_root = self.project_root / "generated/global"
        Renderer(self.model).render("global", generated_root)
        generated_rules = generated_root / "AGENTS.md"
        generated_rules.write_text("stale\n", encoding="utf-8")
        agent_home = self.project_root / "agent-home"
        (agent_home / ".codex").mkdir(parents=True)

        with self.assertRaisesRegex(RulesValidationError, "generated global rules"):
            link_agent_homes(self.model, agent_home, generated_rules)

    def test_agent_home_preflights_every_target_before_retargeting(self) -> None:
        generated_root = self.project_root / "generated/global"
        Renderer(self.model).render("global", generated_root)
        agent_home = self.project_root / "agent-home"
        claude_target = agent_home / ".claude/CLAUDE.md"
        codex_target = agent_home / ".codex/AGENTS.md"
        claude_target.parent.mkdir(parents=True)
        codex_target.parent.mkdir(parents=True)
        claude_target.symlink_to(ROOT / "AGENTS.md")
        external = self.project_root / "external.md"
        external.write_text("external\n", encoding="utf-8")
        codex_target.symlink_to(external)

        with self.assertRaisesRegex(RulesValidationError, "refusing to replace"):
            link_agent_homes(
                self.model, agent_home, generated_root / "AGENTS.md"
            )

        self.assertEqual(claude_target.resolve(), (ROOT / "AGENTS.md").resolve())

    def _git(self, *arguments: str) -> None:
        subprocess.run(
            ["git", *arguments],
            cwd=self.project_root,
            check=True,
            capture_output=True,
            text=True,
        )


if __name__ == "__main__":
    unittest.main()
