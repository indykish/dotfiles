from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


class RulesValidationError(Exception):
    pass


def load_json(path: Path) -> dict[str, Any]:
    try:
        with path.open(encoding="utf-8") as handle:
            value = json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        raise RulesValidationError(f"cannot read JSON object from {path}: {error}") from error
    if not isinstance(value, dict):
        raise RulesValidationError(f"{path} must contain a JSON object")
    return value


def sha256_bytes(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


@dataclass(frozen=True)
class RulesModel:
    root: Path
    registry: dict[str, Any]
    profiles: dict[str, dict[str, Any]]
    repositories: dict[str, Any]

    @classmethod
    def load(cls, root: Path) -> "RulesModel":
        registry = load_json(root / "oracle-rules/registry.json")
        profiles = {
            profile_path.stem: load_json(profile_path)
            for profile_path in sorted((root / "oracle-rules/profiles").glob("*.json"))
        }
        repositories = load_json(root / "oracle-rules/repositories.json")
        return cls(root=root, registry=registry, profiles=profiles, repositories=repositories)

    def validate(self) -> None:
        errors: list[str] = []
        self._validate_registry(errors)
        self._validate_profiles(errors)
        self._validate_rules(errors)
        self._validate_repositories(errors)
        if errors:
            raise RulesValidationError("\n".join(errors))

    def profile(self, name: str) -> dict[str, Any]:
        try:
            return self.profiles[name]
        except KeyError as error:
            raise RulesValidationError(f"unknown profile: {name}") from error

    def repository(self, name: str) -> dict[str, Any]:
        repositories = self.repositories.get("repositories", {})
        try:
            repository = repositories[name]
        except KeyError as error:
            raise RulesValidationError(f"unknown repository: {name}") from error
        if not isinstance(repository, dict):
            raise RulesValidationError(f"repository {name} must be an object")
        return repository

    def registry_digest(self) -> str:
        values: list[tuple[str, Any]] = [
            ("registry", self.registry),
            ("repositories", self.repositories),
        ]
        values.extend(
            (f"profile:{name}", self.profiles[name]) for name in sorted(self.profiles)
        )
        return self._content_digest(values, self._all_rule_sources())

    def profile_digest(self, profile_name: str) -> str:
        profile = self.profile(profile_name)
        selected_packs = {
            name: self.registry["packs"][name] for name in profile["packs"]
        }
        selected_rules = [
            rule
            for rule in self.registry["rules"]
            if rule.get("pack") in selected_packs
        ]
        registry_subset = {
            "schema_version": self.registry["schema_version"],
            "core_documents": self.registry["core_documents"],
            "packs": selected_packs,
            "rules": selected_rules,
        }
        sources = self._implementation_sources()
        sources.update(self.registry["core_documents"])
        for pack in selected_packs.values():
            sources.update(
                managed_file["source"] for managed_file in pack["managed_files"]
            )
        for rule in selected_rules:
            for fixture_paths in rule.get("fixtures", {}).values():
                sources.update(fixture_paths)
        return self._content_digest(
            [("registry", registry_subset), ("profile", profile)], sources
        )

    def _all_rule_sources(self) -> set[str]:
        sources = self._implementation_sources()
        sources.update(self.registry.get("core_documents", []))
        for pack in self.registry.get("packs", {}).values():
            for managed_file in pack.get("managed_files", []):
                source = managed_file.get("source")
                if isinstance(source, str):
                    sources.add(source)
        for rule in self.registry.get("rules", []):
            for fixture_paths in rule.get("fixtures", {}).values():
                sources.update(fixture_paths)
        return sources

    def _implementation_sources(self) -> set[str]:
        sources = {"bin/oracle-rules"}
        for implementation_path in sorted(
            (self.root / "oracle-rules/src/oracle_rules").glob("*.py")
        ):
            sources.add(implementation_path.relative_to(self.root).as_posix())
        for schema_path in sorted((self.root / "oracle-rules/schemas").glob("*.json")):
            sources.add(schema_path.relative_to(self.root).as_posix())
        return sources

    def _content_digest(
        self, values: list[tuple[str, Any]], sources: set[str]
    ) -> str:
        digest = hashlib.sha256()
        for label, value in values:
            digest.update(label.encode("utf-8"))
            digest.update(b"\0")
            digest.update(
                json.dumps(value, sort_keys=True, separators=(",", ":")).encode(
                    "utf-8"
                )
            )
            digest.update(b"\0")
        for source in sorted(sources):
            source_path = self.root / source
            if source_path.is_file():
                digest.update(source.encode("utf-8"))
                digest.update(b"\0")
                digest.update(source_path.read_bytes())
                digest.update(b"\0")
        return digest.hexdigest()

    def _validate_registry(self, errors: list[str]) -> None:
        if self.registry.get("schema_version") != 1:
            errors.append("registry schema_version must equal 1")
        core_documents = self.registry.get("core_documents")
        if not isinstance(core_documents, list) or not core_documents:
            errors.append("registry core_documents must be a non-empty array")
        else:
            for document in core_documents:
                self._validate_relative_path(document, "core document", errors)
                self._require_source(document, "core document", errors)

        packs = self.registry.get("packs")
        if not isinstance(packs, dict) or not packs:
            errors.append("registry packs must be a non-empty object")
            return
        for pack_name, pack in packs.items():
            if not isinstance(pack, dict):
                errors.append(f"pack {pack_name} must be an object")
                continue
            extensions = pack.get("extensions")
            if not isinstance(extensions, list):
                errors.append(f"pack {pack_name} extensions must be an array")
            managed_files = pack.get("managed_files")
            if not isinstance(managed_files, list):
                errors.append(f"pack {pack_name} managed_files must be an array")
                continue
            for managed_file in managed_files:
                if not isinstance(managed_file, dict):
                    errors.append(f"pack {pack_name} managed file must be an object")
                    continue
                source = managed_file.get("source")
                self._validate_relative_path(source, f"pack {pack_name} source", errors)
                self._require_source(source, f"pack {pack_name}", errors)
                target = managed_file.get("target")
                if not isinstance(target, str) or not target:
                    errors.append(f"pack {pack_name} managed target must be a string")
                else:
                    self._validate_relative_path(
                        target, f"pack {pack_name} managed target", errors
                    )

    def _validate_profiles(self, errors: list[str]) -> None:
        packs = self.registry.get("packs", {})
        for profile_name, profile in self.profiles.items():
            if profile.get("schema_version") != 1:
                errors.append(f"profile {profile_name} schema_version must equal 1")
            if profile.get("name") != profile_name:
                errors.append(f"profile {profile_name} name must match its filename")
            selected_packs = profile.get("packs")
            if not isinstance(selected_packs, list):
                errors.append(f"profile {profile_name} packs must be an array")
                continue
            extension_owners: dict[str, str] = {}
            for pack_name in selected_packs:
                if pack_name not in packs:
                    errors.append(f"profile {profile_name} selects unknown pack {pack_name}")
                    continue
                for extension in packs[pack_name].get("extensions", []):
                    previous = extension_owners.get(extension)
                    if previous:
                        errors.append(
                            f"profile {profile_name} extension {extension} has two owners: "
                            f"{previous}, {pack_name}"
                        )
                    extension_owners[extension] = pack_name
            self._validate_commands(profile_name, profile.get("commands"), errors)

    def _validate_commands(
        self, profile_name: str, commands: Any, errors: list[str]
    ) -> None:
        if not isinstance(commands, dict):
            errors.append(f"profile {profile_name} commands must be an object")
            return
        for command_name, invocations in commands.items():
            if not isinstance(invocations, list) or not invocations:
                errors.append(f"profile {profile_name} command {command_name} must be non-empty")
                continue
            for invocation in invocations:
                if not isinstance(invocation, list) or not invocation:
                    errors.append(
                        f"profile {profile_name} command {command_name} invocation must be non-empty"
                    )
                    continue
                if not all(isinstance(argument, str) and argument for argument in invocation):
                    errors.append(
                        f"profile {profile_name} command {command_name} arguments must be strings"
                    )

    def _validate_rules(self, errors: list[str]) -> None:
        rules = self.registry.get("rules")
        if not isinstance(rules, list):
            errors.append("registry rules must be an array")
            return
        packs = self.registry.get("packs", {})
        keys: set[str] = set()
        for rule in rules:
            if not isinstance(rule, dict):
                errors.append("registry rule must be an object")
                continue
            key = rule.get("key")
            if not isinstance(key, str) or not key:
                errors.append("registry rule key must be a string")
                continue
            if key in keys:
                errors.append(f"duplicate rule key: {key}")
            keys.add(key)
            if rule.get("state") not in {"active", "draft", "retired"}:
                errors.append(f"rule {key} has invalid state")
            if rule.get("pack") not in packs:
                errors.append(f"rule {key} selects unknown pack {rule.get('pack')}")
            if rule.get("state") != "active":
                continue
            decision = rule.get("decision")
            if decision == "mechanical":
                self._validate_mechanical_rule(rule, errors)
            elif decision == "repository":
                self._validate_repository_rule(rule, errors)
            elif decision != "judgment":
                errors.append(f"rule {key} has invalid decision {decision}")

    def _validate_mechanical_rule(self, rule: dict[str, Any], errors: list[str]) -> None:
        key = rule["key"]
        checker = rule.get("checker")
        if not isinstance(checker, list) or not checker:
            errors.append(f"mechanical rule {key} needs a checker")
        fixtures = rule.get("fixtures")
        if not isinstance(fixtures, dict):
            errors.append(f"mechanical rule {key} needs fixtures")
            return
        for fixture_kind in ("pass", "fail"):
            fixture_paths = fixtures.get(fixture_kind)
            if not isinstance(fixture_paths, list) or not fixture_paths:
                errors.append(f"mechanical rule {key} needs {fixture_kind} fixtures")
                continue
            for fixture_path in fixture_paths:
                self._require_source(fixture_path, f"rule {key} {fixture_kind} fixture", errors)

    def _validate_repository_rule(self, rule: dict[str, Any], errors: list[str]) -> None:
        key = rule["key"]
        command_name = rule.get("command")
        if not isinstance(command_name, str) or not command_name:
            errors.append(f"repository rule {key} needs a command name")
            return
        selected_pack = rule.get("pack")
        for profile_name, profile in self.profiles.items():
            if selected_pack not in profile.get("packs", []):
                continue
            if command_name not in profile.get("commands", {}):
                errors.append(
                    f"profile {profile_name} selects {selected_pack} but lacks {command_name}"
                )

    def _validate_repositories(self, errors: list[str]) -> None:
        if self.repositories.get("schema_version") != 1:
            errors.append("repositories schema_version must equal 1")
        repositories = self.repositories.get("repositories")
        if not isinstance(repositories, dict):
            errors.append("repositories must be an object")
            return
        for repository_name, repository in repositories.items():
            if not isinstance(repository, dict):
                errors.append(f"repository {repository_name} must be an object")
                continue
            if repository.get("profile") not in self.profiles:
                errors.append(f"repository {repository_name} selects unknown profile")
            path = repository.get("path")
            if not isinstance(path, str) or not path:
                errors.append(f"repository {repository_name} path must be a string")

    def _require_source(self, source: Any, label: str, errors: list[str]) -> None:
        if not isinstance(source, str) or not source:
            errors.append(f"{label} source must be a string")
            return
        if not (self.root / source).is_file():
            errors.append(f"{label} source is missing: {source}")

    @staticmethod
    def _validate_relative_path(path: Any, label: str, errors: list[str]) -> None:
        if not isinstance(path, str) or not path:
            return
        candidate = Path(path)
        if candidate.is_absolute() or ".." in candidate.parts:
            errors.append(f"{label} must stay below the output root: {path}")
