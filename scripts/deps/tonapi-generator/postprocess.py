#!/usr/bin/env python3
"""Post-process swift-openapi-generator output for TonAPI.

`Components.Schemas.Action` is generated with a required `_type` property backed by a frozen
enum of every action kind tonapi knew in 2024. tonapi adds action kinds over time, and one unknown
kind would make a whole history page fail to decode. The property is therefore dropped, exactly
as in the client the app shipped before 4.2.1 (ton-api-swift 0.1.7), and the app reads each
action's kind from the optional per-kind payloads instead.

Usage: postprocess.py <Types.swift>   (edits the file in place; fails if the shape is unexpected)
"""
import pathlib
import sys

MARKER = "            /// - Remark: Generated from `#/components/schemas/Action/type`.\n"
PROPERTY = "            public var _type: Components.Schemas.Action._typePayload\n"
REMOVALS = [
    MARKER,
    PROPERTY,
    "                _type: Components.Schemas.Action._typePayload,\n",
    "                self._type = _type\n",
    "                case _type = \"type\"\n",
]
WINDOW = 200


def main(path):
    file = pathlib.Path(path)
    lines = file.read_text().splitlines(keepends=True)
    # The same doc comment also sits on the `_typePayload` enum; anchor on the property.
    if lines.count(PROPERTY) != 1:
        raise SystemExit("Action._type property not found exactly once")
    start = lines.index(PROPERTY) - 1
    if lines[start] != MARKER:
        raise SystemExit("Action._type property lost its doc comment")
    region = lines[start:start + WINDOW]
    for line in REMOVALS:
        if region.count(line) != 1:
            raise SystemExit("expected exactly one %r near Action/type" % line.strip())
        region.remove(line)
    file.write_text("".join(lines[:start] + region + lines[start + WINDOW:]))


if __name__ == "__main__":
    main(sys.argv[1])
