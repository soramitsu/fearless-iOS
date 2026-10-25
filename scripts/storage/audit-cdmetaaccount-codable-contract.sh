#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly ROOT_DIR="${FEARLESS_CDMETAACCOUNT_CODABLE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd -P)}"
readonly SOURCE_DIR="$ROOT_DIR/fearless"
readonly PYTHON_BIN="${FEARLESS_CDMETAACCOUNT_CODABLE_PYTHON_BIN:-python3}"
readonly LOG_PREFIX="[cdmetaaccount-codable-audit]"

fail() {
  printf '%s ERROR: %s\n' "$LOG_PREFIX" "$*" >&2
  exit 1
}

if [[ "$PYTHON_BIN" == */* ]]; then
  [[ -x "$PYTHON_BIN" ]] || fail "python interpreter is not executable"
else
  command -v "$PYTHON_BIN" >/dev/null 2>&1 ||
    fail "python3 is required"
fi

[[ -d "$SOURCE_DIR" && ! -L "$SOURCE_DIR" ]] ||
  fail "fearless source directory is missing or unsafe"

"$PYTHON_BIN" - "$SOURCE_DIR" <<'PY'
import bisect
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

source_dir = Path(sys.argv[1]).resolve()
token_pattern = re.compile(r"[A-Za-z_][A-Za-z0-9_]*|[<>{}:,.()\[\]]")
declaration_keywords = {"extension", "class", "struct", "enum", "actor"}


@dataclass(frozen=True)
class Token:
    value: str
    offset: int


def mask_comments(source: str) -> str:
    """Remove line and nested block comments while preserving source offsets."""
    masked = list(source)
    index = 0
    size = len(source)

    def blank(start: int, end: int) -> None:
        for position in range(start, end):
            if masked[position] not in "\r\n":
                masked[position] = " "

    while index < size:
        if source.startswith("//", index):
            end = source.find("\n", index + 2)
            if end == -1:
                end = size
            blank(index, end)
            index = end
            continue

        if source.startswith("/*", index):
            start = index
            depth = 1
            index += 2
            while index < size and depth:
                if source.startswith("/*", index):
                    depth += 1
                    index += 2
                elif source.startswith("*/", index):
                    depth -= 1
                    index += 2
                else:
                    index += 1
            blank(start, index)
            continue

        index += 1

    return "".join(masked)


def line_number(line_offsets: list[int], offset: int) -> int:
    return bisect.bisect_right(line_offsets, offset)


def direct_conformance(tokens: list[Token], start: int) -> Optional[Token]:
    angle_depth = 0
    top_level_identifiers: list[Token] = []
    colon_index = None

    for index in range(start + 1, len(tokens)):
        token = tokens[index]
        if token.value == "<":
            angle_depth += 1
        elif token.value == ">":
            angle_depth = max(0, angle_depth - 1)
        elif angle_depth == 0 and token.value in {"{", "where"}:
            break
        elif angle_depth == 0 and token.value == ":":
            colon_index = index
            break
        elif angle_depth == 0 and token.value[0].isalpha():
            top_level_identifiers.append(token)

    if colon_index is None or not top_level_identifiers:
        return None
    if top_level_identifiers[-1].value != "CDMetaAccount":
        return None

    angle_depth = 0
    for token in tokens[colon_index + 1:]:
        if token.value == "<":
            angle_depth += 1
        elif token.value == ">":
            angle_depth = max(0, angle_depth - 1)
        elif angle_depth == 0 and token.value in {"{", "where"}:
            break
        elif token.value == "CoreDataCodable":
            return token

    return None


def mapper_second_argument(tokens: list[Token], start: int) -> Optional[Token]:
    if start + 1 >= len(tokens) or tokens[start + 1].value != "<":
        return None

    angle_depth = 1
    parenthesis_depth = 0
    bracket_depth = 0
    argument_index = 0

    for token in tokens[start + 2:]:
        if token.value == "<":
            angle_depth += 1
        elif token.value == ">":
            angle_depth -= 1
            if angle_depth == 0:
                break
        elif token.value == "(":
            parenthesis_depth += 1
        elif token.value == ")":
            parenthesis_depth = max(0, parenthesis_depth - 1)
        elif token.value == "[":
            bracket_depth += 1
        elif token.value == "]":
            bracket_depth = max(0, bracket_depth - 1)
        elif (
            token.value == ","
            and angle_depth == 1
            and parenthesis_depth == 0
            and bracket_depth == 0
        ):
            argument_index += 1
            continue

        if argument_index == 1 and token.value == "CDMetaAccount":
            return token

    return None


violations: list[tuple[str, int, str]] = []
swift_files: list[Path] = []

for directory, directory_names, file_names in os.walk(source_dir, followlinks=False):
    directory_names.sort()
    file_names.sort()
    for directory_name in directory_names:
        candidate = Path(directory, directory_name)
        if candidate.is_symlink():
            relative = candidate.relative_to(source_dir)
            print(
                f"[cdmetaaccount-codable-audit] ERROR: "
                f"symlinked source directory is forbidden: fearless/{relative}",
                file=sys.stderr,
            )
            raise SystemExit(1)
    for file_name in file_names:
        if not file_name.endswith(".swift"):
            continue
        candidate = Path(directory, file_name)
        if candidate.is_symlink() or not candidate.is_file():
            relative = candidate.relative_to(source_dir)
            print(
                f"[cdmetaaccount-codable-audit] ERROR: "
                f"unsafe Swift source is forbidden: fearless/{relative}",
                file=sys.stderr,
            )
            raise SystemExit(1)
        swift_files.append(candidate)

if not swift_files:
    print(
        "[cdmetaaccount-codable-audit] ERROR: no Swift source files were found",
        file=sys.stderr,
    )
    raise SystemExit(1)

for path in swift_files:
    try:
        source = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        print(
            f"[cdmetaaccount-codable-audit] ERROR: unreadable Swift source "
            f"{path}: {error}",
            file=sys.stderr,
        )
        raise SystemExit(1)

    code = mask_comments(source)
    tokens = [
        Token(match.group(0), match.start())
        for match in token_pattern.finditer(code)
    ]
    line_offsets = [0]
    line_offsets.extend(
        index + 1
        for index, character in enumerate(source)
        if character == "\n"
    )
    relative = f"fearless/{path.relative_to(source_dir)}"

    for index, token in enumerate(tokens):
        if token.value in declaration_keywords:
            violation = direct_conformance(tokens, index)
            if violation is not None:
                violations.append(
                    (
                        relative,
                        line_number(line_offsets, violation.offset),
                        "CDMetaAccount must not directly conform to CoreDataCodable",
                    )
                )
        elif token.value == "CodableCoreDataMapper":
            violation = mapper_second_argument(tokens, index)
            if violation is not None:
                violations.append(
                    (
                        relative,
                        line_number(line_offsets, violation.offset),
                        "CodableCoreDataMapper must not target CDMetaAccount",
                    )
                )

if violations:
    for path, line, message in sorted(set(violations)):
        print(
            f"[cdmetaaccount-codable-audit] ERROR: {path}:{line}: {message}",
            file=sys.stderr,
        )
    raise SystemExit(1)

print(
    "[cdmetaaccount-codable-audit] PASS: explicit MetaAccountMapper boundary preserved"
)
PY
