#!/usr/bin/env python3
"""Validate iOS-owned configuration and ensure nested asset URLs are self-contained."""
import json
from pathlib import Path
import sys
from urllib.parse import unquote, urlsplit

REPOSITORY = "fearless-iOS"
BASE = "https://raw.githubusercontent.com/soramitsu/" + REPOSITORY + "/master/remote-config/"
RETIRED = ("/soramitsu/shared-features-utils/", "/soramitsu/fearless-utils/")


def validate(root):
    root = Path(root).resolve()
    config = root / "remote-config"
    inventory = {path.relative_to(config).as_posix() for path in config.rglob("*") if path.is_file()}
    failures = []
    counts = {"documents": 0, "ownedReferences": 0}

    def visit(value, source):
        if isinstance(value, dict):
            for child in value.values():
                visit(child, source)
        elif isinstance(value, list):
            for child in value:
                visit(child, source)
        elif isinstance(value, str):
            if any(fragment in value for fragment in RETIRED):
                failures.append(str(source) + ": retired config URL")
            if value.startswith(BASE):
                counts["ownedReferences"] += 1
                relative = unquote(urlsplit(value[len(BASE):]).path)
                target = (config / relative).resolve()
                if relative not in inventory or config.resolve() not in target.parents or not target.is_file():
                    failures.append(str(source) + ": missing owned asset " + relative)

    for file in sorted(config.rglob("*")):
        if not file.is_file() or (file.suffix != ".json" and file.name != "feature_toggle"):
            continue
        counts["documents"] += 1
        try:
            visit(json.loads(file.read_text()), file.relative_to(root))
        except (ValueError, UnicodeError) as error:
            failures.append(str(file.relative_to(root)) + ": " + str(error))
    if counts["documents"] == 0:
        failures.append("No owned configuration documents found")
    if failures:
        raise ValueError("\n".join(failures))
    return counts


if __name__ == "__main__":
    try:
        print(json.dumps(validate(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]), sort_keys=True))
    except (ValueError, OSError) as error:
        sys.exit(str(error))
