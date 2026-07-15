from __future__ import annotations

import json
import tempfile
from datetime import UTC, datetime
from pathlib import Path

from .model import RulesModel
from .render import Renderer


def verify_all_profiles(model: RulesModel) -> list[dict[str, str]]:
    model.validate()
    checks: list[dict[str, str]] = []
    renderer = Renderer(model)
    for profile_name in sorted(model.profiles):
        with tempfile.TemporaryDirectory(prefix=f"oracle-rules-{profile_name}-a-") as first_dir:
            with tempfile.TemporaryDirectory(
                prefix=f"oracle-rules-{profile_name}-b-"
            ) as second_dir:
                first_root = Path(first_dir)
                second_root = Path(second_dir)
                first_hashes = renderer.render(profile_name, first_root)
                second_hashes = renderer.render(profile_name, second_root)
                result = "pass" if first_hashes == second_hashes else "fail"
                checks.append(
                    {
                        "name": f"render.{profile_name}.idempotent",
                        "result": result,
                    }
                )
    managed_outputs = {
        "generated.global.current": model.root / "oracle-rules/generated/global",
        "generated.dotfiles.current": model.root,
    }
    for check_name, output_root in managed_outputs.items():
        errors = renderer.verify_lock(output_root)
        checks.append(
            {
                "name": check_name,
                "result": "pass" if not errors else "fail",
                "detail": "; ".join(errors),
            }
        )
    return checks


def write_evidence(
    model: RulesModel,
    profile_name: str,
    checks: list[dict[str, str]],
    llm_result: str,
) -> Path:
    result = "pass" if all(check["result"] == "pass" for check in checks) else "fail"
    evidence = {
        "schema_version": 1,
        "profile": profile_name,
        "source_commit": _source_commit(model.root),
        "registry_digest": model.registry_digest(),
        "result": result,
        "checks": checks,
        "llm_result": llm_result,
        "created_at": datetime.now(UTC).replace(microsecond=0).isoformat(),
    }
    evidence_path = model.root / ".oracle/evidence.json"
    evidence_path.parent.mkdir(parents=True, exist_ok=True)
    evidence_path.write_text(
        json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return evidence_path


def _source_commit(root: Path) -> str:
    import subprocess

    result = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else "uncommitted"
