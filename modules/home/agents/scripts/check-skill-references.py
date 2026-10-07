#!/usr/bin/env python3
"""Check mandatory skill:// references and Markdown links to SKILL.md in source catalogs."""

import argparse
import re
from pathlib import Path


def check_catalogs(roots):
    skills = {}
    errors = []
    files = set()
    for root in roots:
        if not root.is_dir():
            errors.append(f"{root}: skill catalog not found")
            continue
        files.update(root.rglob("*.md"))
        for path in root.rglob("SKILL.md"):
            text = path.read_text()
            frontmatter = re.match(r"\A---\n(.*?)\n---(?:\n|$)", text, re.S)
            name = (
                re.search(r"^name:\s*['\"]?([a-z0-9-]+)['\"]?\s*$", frontmatter[1], re.M)
                if frontmatter else None
            )
            if not name:
                errors.append(f"{path}: missing skill name/frontmatter")
                continue
            if name[1] != path.parent.name:
                errors.append(f"{path}: name {name[1]!r} does not match directory")
            if name[1] in skills and skills[name[1]] != path:
                errors.append(f"{path}: duplicate skill {name[1]!r}, also at {skills[name[1]]}")
            skills[name[1]] = path

    for path in sorted(files):
        for line_number, line in enumerate(path.read_text().splitlines(), 1):
            for name in re.findall(r"skill://([a-z0-9-]+)", line):
                if name not in skills:
                    errors.append(f"{path}:{line_number}: unknown mandatory skill {name!r}")
            for target in re.findall(r"\]\(([^)\s]*SKILL\.md)(?:#[^)]*)?\)", line):
                if not target.startswith(("https://", "http://")) and not (path.parent / target).is_file():
                    errors.append(f"{path}:{line_number}: broken skill link {target!r}")
    return skills, errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalogs", nargs="*", type=Path, help="additional project or plugin skill catalogs")
    args = parser.parse_args()
    global_catalog = Path(__file__).resolve().parents[1] / "skills"
    roots = list(dict.fromkeys(root.resolve() for root in [global_catalog, *args.catalogs]))
    skills, errors = check_catalogs(roots)
    if errors:
        print("\n".join(errors))
        return 1
    print(f"Skill references OK: {len(skills)} skills across {len(roots)} catalogs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
