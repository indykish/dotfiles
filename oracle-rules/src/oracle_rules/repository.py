from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from .model import RulesModel, RulesValidationError, load_json
from .render import Renderer


AGENT_HOME_TARGETS = (
    ".claude/CLAUDE.md",
    ".codex/AGENTS.md",
    ".config/opencode/AGENTS.md",
    ".amp/AGENTS.md",
)
PROJECT_INSTRUCTIONS_PATH = "AGENTS.project.md"
PROFILE_PATH = ".oracle/profile.json"
RULESET_LOCK_PATH = ".oracle/ruleset.lock"


def repository_path(model: RulesModel, repository_name: str) -> Path:
    repository = model.repository(repository_name)
    return Path(os.path.expanduser(repository["path"])).resolve()


def git_status(project_root: Path) -> list[str]:
    result = subprocess.run(
        ["git", "status", "--porcelain=v1", "-uall"],
        cwd=project_root,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RulesValidationError(f"not a Git repository: {project_root}")
    return [line for line in result.stdout.splitlines() if line]


def sync_repository(model: RulesModel, repository_name: str) -> list[str]:
    project_root = repository_path(model, repository_name)
    if not project_root.is_dir():
        raise RulesValidationError(f"repository is missing: {project_root}")
    dirty = git_status(project_root)
    if dirty:
        raise RulesValidationError(
            "repository must be clean before sync:\n" + "\n".join(dirty)
        )
    project_instructions = project_root / PROJECT_INSTRUCTIONS_PATH
    if not project_instructions.is_file():
        raise RulesValidationError(
            f"{project_instructions} is required before replacing AGENTS.md"
        )
    repository = model.repository(repository_name)
    profile_name = repository["profile"]
    renderer = Renderer(model)
    with tempfile.TemporaryDirectory(prefix="oracle-rules-sync-") as temp_dir:
        rendered_root = Path(temp_dir)
        renderer.render(profile_name, rendered_root, project_root)
        managed_files = load_json(rendered_root / ".oracle/managed-files.json")["files"]
        managed_files.append(RULESET_LOCK_PATH)
        prior_managed = _prior_managed_files(project_root, profile_name, renderer)
        errors = _replacement_errors(
            model, project_root, rendered_root, managed_files, prior_managed
        )
        if errors:
            raise RulesValidationError("\n".join(errors))
        copied: list[str] = []
        for relative_path in managed_files:
            source_path = rendered_root / relative_path
            target_path = project_root / relative_path
            target_path.parent.mkdir(parents=True, exist_ok=True)
            if target_path.is_symlink():
                target_path.unlink()
            shutil.copy2(source_path, target_path)
            copied.append(relative_path)
    return sorted(copied)


def initialize_repository(
    model: RulesModel, profile_name: str, project_root: Path
) -> list[str]:
    model.profile(profile_name)
    project_root = project_root.resolve()
    if not (project_root / ".git").exists():
        raise RulesValidationError(f"not a Git repository: {project_root}")
    dirty = git_status(project_root)
    if dirty:
        raise RulesValidationError(
            "repository must be clean before initialization:\n" + "\n".join(dirty)
        )
    project_instructions = project_root / PROJECT_INSTRUCTIONS_PATH
    if project_instructions.exists():
        raise RulesValidationError(f"already exists: {project_instructions}")
    profile_path = project_root / PROFILE_PATH
    if profile_path.exists() or profile_path.is_symlink():
        raise RulesValidationError(f"already exists: {profile_path}")
    project_instructions.write_text(
        "# Repository instructions\n\n"
        "Add repository commands, terminology, architecture triggers, and local safety rules.\n",
        encoding="utf-8",
    )
    profile_path.parent.mkdir(parents=True, exist_ok=True)
    profile_path.write_text(
        json.dumps(model.profile(profile_name), indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return [PROJECT_INSTRUCTIONS_PATH, PROFILE_PATH]


def _replacement_errors(
    model: RulesModel,
    project_root: Path,
    rendered_root: Path,
    managed_files: list[str],
    prior_managed: set[str],
) -> list[str]:
    errors: list[str] = []
    for relative_path in managed_files:
        target_path = project_root / relative_path
        if not target_path.parent.resolve().is_relative_to(project_root):
            errors.append(f"managed path escapes repository: {relative_path}")
            continue
        if not target_path.exists() and not target_path.is_symlink():
            continue
        if relative_path in prior_managed:
            continue
        if target_path.is_symlink() and target_path.resolve().is_relative_to(
            model.root.resolve()
        ):
            continue
        rendered_path = rendered_root / relative_path
        if (
            relative_path == PROFILE_PATH
            and target_path.is_file()
            and not target_path.is_symlink()
            and target_path.read_bytes() == rendered_path.read_bytes()
        ):
            continue
        errors.append(f"refusing to replace unmanaged path: {relative_path}")
    return errors


def doctor_repository(model: RulesModel, repository_name: str) -> list[str]:
    project_root = repository_path(model, repository_name)
    if not project_root.is_dir():
        return [f"repository is missing: {project_root}"]
    expected_profile = model.repository(repository_name)["profile"]
    return Renderer(model).verify_lock(project_root, expected_profile)


def link_agent_homes(
    model: RulesModel,
    home: Path | None = None,
    generated: Path | None = None,
) -> list[str]:
    generated_rules = generated or model.root / "oracle-rules/generated/global/AGENTS.md"
    if not generated_rules.is_file():
        raise RulesValidationError(
            f"generated global rules are missing: {generated_rules}"
        )
    generated_errors = Renderer(model).verify_lock(generated_rules.parent, "global")
    if generated_errors:
        raise RulesValidationError(
            "generated global rules are stale:\n" + "\n".join(generated_errors)
        )
    linked: list[str] = []
    agent_home = home or Path.home()
    dotfiles_root = model.root.resolve()
    targets = [
        agent_home / relative_target
        for relative_target in AGENT_HOME_TARGETS
        if (agent_home / relative_target).parent.is_dir()
    ]
    for target in targets:
        if target.is_symlink() and target.resolve().is_relative_to(dotfiles_root):
            continue
        if target.exists() or target.is_symlink():
            raise RulesValidationError(f"refusing to replace agent-home file: {target}")
    for target in targets:
        if target.is_symlink() and target.resolve() == generated_rules.resolve():
            linked.append(str(target))
            continue
        if target.is_symlink() and target.resolve().is_relative_to(dotfiles_root):
            target.unlink()
        elif target.exists() or target.is_symlink():
            raise RulesValidationError(f"refusing to replace agent-home file: {target}")
        target.symlink_to(generated_rules)
        linked.append(str(target))
    return linked


def _prior_managed_files(
    project_root: Path, profile_name: str, renderer: Renderer
) -> set[str]:
    manifest_path = project_root / ".oracle/managed-files.json"
    lock_path = project_root / RULESET_LOCK_PATH
    if not manifest_path.exists() and not lock_path.exists():
        return set()
    if not manifest_path.is_file() or not lock_path.is_file():
        raise RulesValidationError("repository has a partial Oracle rules snapshot")
    errors = [
        error
        for error in renderer.verify_lock(project_root, profile_name)
        if error != "repository ruleset is behind its current profile"
    ]
    if errors:
        raise RulesValidationError(
            "existing Oracle rules snapshot is not safe to replace:\n"
            + "\n".join(errors)
        )
    manifest = load_json(manifest_path)
    files = manifest.get("files")
    if not isinstance(files, list) or not all(isinstance(path, str) for path in files):
        raise RulesValidationError("managed-files manifest must contain string paths")
    for relative_path in files:
        path = Path(relative_path)
        if path.is_absolute() or ".." in path.parts:
            raise RulesValidationError(
                f"managed path escapes repository: {relative_path}"
            )
    return set(files) | {RULESET_LOCK_PATH}


def doctor_agent_homes(
    model: RulesModel,
    home: Path | None = None,
    generated: Path | None = None,
) -> list[str]:
    generated_rules = generated or model.root / "oracle-rules/generated/global/AGENTS.md"
    if not generated_rules.is_file():
        return [f"generated global rules are missing: {generated_rules}"]
    errors = Renderer(model).verify_lock(generated_rules.parent, "global")
    agent_home = home or Path.home()
    for relative_target in AGENT_HOME_TARGETS:
        target = agent_home / relative_target
        if not target.parent.is_dir():
            continue
        if not target.is_symlink():
            errors.append(f"agent-home instructions are not linked: {target}")
            continue
        if target.resolve() != generated_rules.resolve():
            errors.append(f"agent-home instructions point elsewhere: {target}")
    return errors
