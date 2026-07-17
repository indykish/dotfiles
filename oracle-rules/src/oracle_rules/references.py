from __future__ import annotations

import re
from pathlib import Path
from urllib.parse import unquote


PACK_LINE = re.compile(r"^(?P<body>.*?)[ \t]*<!-- oracle-packs:(?P<packs>[^>]+) -->[ \t]*$")
PACK_START = re.compile(r"^[ \t]*<!-- oracle-packs:start (?P<packs>[^>]+) -->[ \t]*$")
PACK_END = re.compile(r"^[ \t]*<!-- oracle-packs:end -->[ \t]*$")
MARKDOWN_LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
DISPATCH_REFERENCE = re.compile(r"dispatch/[A-Za-z0-9_.-]+\.md")


class SnapshotReferenceError(Exception):
    pass


def render_profile_text(
    content: str,
    selected_packs: set[str],
    known_packs: set[str],
    source: str,
) -> str:
    rendered: list[str] = []
    active_block: tuple[str, ...] | None = None
    include_block = True
    for line_number, line in enumerate(content.splitlines(), 1):
        start_match = PACK_START.fullmatch(line)
        if start_match:
            if active_block is not None:
                raise SnapshotReferenceError(
                    f"{source}:{line_number}: nested oracle pack block"
                )
            active_block = _pack_names(
                start_match.group("packs"), known_packs, source, line_number
            )
            include_block = bool(selected_packs.intersection(active_block))
            continue
        if PACK_END.fullmatch(line):
            if active_block is None:
                raise SnapshotReferenceError(
                    f"{source}:{line_number}: unmatched oracle pack block end"
                )
            active_block = None
            include_block = True
            continue
        if active_block is not None and not include_block:
            continue
        line_match = PACK_LINE.fullmatch(line)
        if line_match:
            line_packs = _pack_names(
                line_match.group("packs"), known_packs, source, line_number
            )
            if selected_packs.intersection(line_packs):
                rendered.append(line_match.group("body").rstrip())
            continue
        rendered.append(line)
    if active_block is not None:
        raise SnapshotReferenceError(f"{source}: unclosed oracle pack block")
    return "\n".join(rendered).strip()


def reference_closure_errors(output_root: Path, rendered_paths: list[Path]) -> list[str]:
    errors: list[str] = []
    root = output_root.resolve()
    markdown_paths = sorted(path for path in rendered_paths if path.suffix == ".md")
    for source_path in markdown_paths:
        relative_source = source_path.relative_to(output_root).as_posix()
        content = source_path.read_text(encoding="utf-8")
        for line_number, line in enumerate(content.splitlines(), 1):
            for raw_target in MARKDOWN_LINK.findall(line):
                target = _markdown_target(raw_target)
                if target is None:
                    continue
                resolved = (source_path.parent / target).resolve()
                if not _is_below(resolved, root):
                    errors.append(
                        f"snapshot reference escapes repository: "
                        f"{relative_source}:{line_number} -> {raw_target}"
                    )
                elif not resolved.exists():
                    errors.append(
                        f"missing snapshot reference: "
                        f"{relative_source}:{line_number} -> {raw_target}"
                    )
            if relative_source == "AGENTS.md":
                for target in DISPATCH_REFERENCE.findall(line):
                    if not (output_root / target).is_file():
                        errors.append(
                            f"missing dispatch reference: "
                            f"{relative_source}:{line_number} -> {target}"
                        )
    return sorted(set(errors))


def _pack_names(
    value: str, known_packs: set[str], source: str, line_number: int
) -> tuple[str, ...]:
    names = tuple(name.strip() for name in value.split(",") if name.strip())
    if not names:
        raise SnapshotReferenceError(
            f"{source}:{line_number}: oracle pack marker must name a pack"
        )
    unknown = sorted(set(names) - known_packs)
    if unknown:
        raise SnapshotReferenceError(
            f"{source}:{line_number}: unknown oracle pack marker: {', '.join(unknown)}"
        )
    return names


def _markdown_target(raw_target: str) -> str | None:
    target = raw_target.strip().split(maxsplit=1)[0].strip("<>")
    target = unquote(target.split("#", 1)[0])
    if not target or target.startswith(("/", "http://", "https://", "mailto:", "app://")):
        return None
    return target


def _is_below(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True
