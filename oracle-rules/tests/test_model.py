from __future__ import annotations

import copy
import unittest
from pathlib import Path

from oracle_rules.model import RulesModel, RulesValidationError, load_json


ROOT = Path(__file__).resolve().parents[2]


class RulesModelTests(unittest.TestCase):
    def test_current_registry_is_valid(self) -> None:
        model = RulesModel.load(ROOT)

        model.validate()

    def test_declared_registry_pass_fixture_passes(self) -> None:
        model = self._fixture_model("registry-valid.json")

        model.validate()

    def test_declared_registry_fail_fixture_fails(self) -> None:
        model = self._fixture_model("registry-invalid.json")

        with self.assertRaises(RulesValidationError):
            model.validate()

    def test_duplicate_language_owner_is_rejected(self) -> None:
        model = RulesModel.load(ROOT)
        registry = copy.deepcopy(model.registry)
        profiles = copy.deepcopy(model.profiles)
        registry["packs"]["language.second-zig"] = {
            "extensions": [".zig"],
            "managed_files": [],
        }
        profiles["agentsfleet"]["packs"].append("language.second-zig")
        invalid_model = RulesModel(
            root=model.root,
            registry=registry,
            profiles=profiles,
            repositories=model.repositories,
        )

        with self.assertRaisesRegex(RulesValidationError, "two owners"):
            invalid_model.validate()

    def test_active_mechanical_rule_requires_both_fixture_kinds(self) -> None:
        model = RulesModel.load(ROOT)
        registry = copy.deepcopy(model.registry)
        registry["rules"][0]["fixtures"]["fail"] = []
        invalid_model = RulesModel(
            root=model.root,
            registry=registry,
            profiles=model.profiles,
            repositories=model.repositories,
        )

        with self.assertRaisesRegex(RulesValidationError, "needs fail fixtures"):
            invalid_model.validate()

    def test_managed_target_cannot_escape_output_root(self) -> None:
        model = RulesModel.load(ROOT)
        registry = copy.deepcopy(model.registry)
        registry["packs"]["universal.authoring"]["managed_files"][0][
            "target"
        ] = "../AGENTS.md"
        invalid_model = RulesModel(
            root=model.root,
            registry=registry,
            profiles=model.profiles,
            repositories=model.repositories,
        )

        with self.assertRaisesRegex(RulesValidationError, "stay below"):
            invalid_model.validate()

    def test_agentsfleet_preserves_repository_harness(self) -> None:
        model = RulesModel.load(ROOT)

        self.assertEqual(
            model.profile("agentsfleet")["commands"]["conform"],
            [["make", "harness-verify"]],
        )

    def test_registry_digest_includes_profile_commands(self) -> None:
        model = RulesModel.load(ROOT)
        profiles = copy.deepcopy(model.profiles)
        profiles["agentsfleet"]["commands"]["conform"] = [["make", "other"]]
        changed_model = RulesModel(
            root=model.root,
            registry=model.registry,
            profiles=profiles,
            repositories=model.repositories,
        )

        self.assertNotEqual(model.registry_digest(), changed_model.registry_digest())
        self.assertNotEqual(
            model.profile_digest("agentsfleet"),
            changed_model.profile_digest("agentsfleet"),
        )
        self.assertEqual(
            model.profile_digest("cache-kit"),
            changed_model.profile_digest("cache-kit"),
        )

    @staticmethod
    def _fixture_model(fixture_name: str) -> RulesModel:
        return RulesModel(
            root=ROOT,
            registry=load_json(ROOT / "oracle-rules/tests/fixtures" / fixture_name),
            profiles={},
            repositories={"schema_version": 1, "repositories": {}},
        )


if __name__ == "__main__":
    unittest.main()
