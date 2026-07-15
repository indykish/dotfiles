from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .model import RulesModel, RulesValidationError
from .render import Renderer
from .repository import (
    doctor_agent_homes,
    doctor_repository,
    initialize_repository,
    link_agent_homes,
    repository_path,
    sync_repository,
)
from .verify import verify_all_profiles, write_evidence


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="oracle-rules")
    parser.add_argument("--root", type=Path, default=_default_root())
    commands = parser.add_subparsers(dest="command", required=True)

    commands.add_parser("validate")
    commands.add_parser("list")

    render_parser = commands.add_parser("render")
    render_parser.add_argument("--profile", required=True)
    render_parser.add_argument("--output", required=True, type=Path)
    render_parser.add_argument("--project-root", type=Path)

    init_parser = commands.add_parser("init")
    init_parser.add_argument("--profile", required=True)
    init_parser.add_argument("--repository", required=True, type=Path)

    sync_parser = commands.add_parser("sync")
    sync_parser.add_argument("--repository", required=True)

    doctor_parser = commands.add_parser("doctor")
    doctor_group = doctor_parser.add_mutually_exclusive_group(required=True)
    doctor_group.add_argument("--repository")
    doctor_group.add_argument("--all", action="store_true")

    link_parser = commands.add_parser("link-agent-homes")
    link_parser.add_argument("--check", action="store_true")

    status_parser = commands.add_parser("status")
    status_parser.add_argument("--all", action="store_true", required=True)

    verify_parser = commands.add_parser("verify")
    verify_parser.add_argument("--all", action="store_true", required=True)
    verify_parser.add_argument("--write-evidence", action="store_true")
    verify_parser.add_argument(
        "--llm-result", choices=("pass", "not-required"), default="not-required"
    )
    return parser


def main(arguments: list[str] | None = None) -> int:
    parser = build_parser()
    options = parser.parse_args(arguments)
    try:
        model = RulesModel.load(options.root.resolve())
        if options.command == "validate":
            model.validate()
            print("oracle-rules: registry and profiles valid")
            return 0
        if options.command == "list":
            return _list(model)
        if options.command == "render":
            model.validate()
            hashes = Renderer(model).render(
                options.profile, options.output.resolve(), options.project_root
            )
            print(json.dumps(hashes, indent=2, sort_keys=True))
            return 0
        if options.command == "init":
            model.validate()
            files = initialize_repository(model, options.profile, options.repository)
            _print_paths("initialized", files)
            return 0
        if options.command == "sync":
            model.validate()
            files = sync_repository(model, options.repository)
            _print_paths("synced", files)
            return 0
        if options.command == "doctor":
            model.validate()
            return _doctor(model, options.repository, options.all)
        if options.command == "link-agent-homes":
            model.validate()
            if options.check:
                errors = doctor_agent_homes(model)
                if errors:
                    for error in errors:
                        print(f"🔴 {error}")
                    return 1
                print("🟢 agent-home instructions use the generated global rules")
                return 0
            _print_paths("linked", link_agent_homes(model))
            return 0
        if options.command == "status":
            model.validate()
            return _status(model)
        if options.command == "verify":
            checks = verify_all_profiles(model)
            for check in checks:
                glyph = "🟢" if check["result"] == "pass" else "🔴"
                detail = f": {check['detail']}" if check.get("detail") else ""
                print(f"{glyph} {check['name']}{detail}")
            if options.write_evidence:
                evidence_path = write_evidence(
                    model, "dotfiles", checks, options.llm_result
                )
                print(f"evidence: {evidence_path}")
            return 0 if all(check["result"] == "pass" for check in checks) else 1
    except RulesValidationError as error:
        print(f"oracle-rules: {error}", file=sys.stderr)
        return 1
    parser.error(f"unknown command: {options.command}")
    return 2


def _default_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _list(model: RulesModel) -> int:
    repositories = model.repositories["repositories"]
    for repository_name in sorted(repositories):
        repository = repositories[repository_name]
        print(
            f"{repository_name}\t{repository['profile']}\t"
            f"{repository_path(model, repository_name)}"
        )
    return 0


def _doctor(model: RulesModel, repository_name: str | None, all_repositories: bool) -> int:
    names = (
        sorted(model.repositories["repositories"])
        if all_repositories
        else [repository_name]
    )
    failed = False
    for name in names:
        errors = doctor_repository(model, name)
        if errors:
            failed = True
            print(f"🔴 {name}: " + "; ".join(errors))
        else:
            print(f"🟢 {name}: managed files match the ruleset lock")
    return 1 if failed else 0


def _status(model: RulesModel) -> int:
    for repository_name in sorted(model.repositories["repositories"]):
        errors = doctor_repository(model, repository_name)
        status = "current" if not errors else "update-required"
        print(f"{repository_name}\t{status}\t" + "; ".join(errors))
    return 0


def _print_paths(action: str, paths: list[str]) -> None:
    for path in paths:
        print(f"{action}: {path}")


if __name__ == "__main__":
    raise SystemExit(main())
