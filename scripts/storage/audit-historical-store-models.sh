#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MODELS_ROOT="${FEARLESS_HISTORICAL_STORE_MODELS_ROOT:-$ROOT_DIR/fearless/Common/Storage/HistoricalStoreModels}"
FIXTURES_ROOT="${FEARLESS_HISTORICAL_STORE_MODEL_FIXTURES_ROOT:-$ROOT_DIR/fearlessTests/Resources/HistoricalStoreModels}"
SUBSTRATE_LINEAGE_ROOT="${FEARLESS_SUBSTRATE_ACTIVE_MODEL_ROOT:-$ROOT_DIR/fearless/Common/Storage/SubstrateDataModel.xcdatamodeld}"
# The app opens User stores with the shared-features copy of these models;
# `--repos` proves this checkout's sources hash identically.
USER_LINEAGE_ROOT="${FEARLESS_USER_LINEAGE_MODEL_ROOT:-$ROOT_DIR/fearless/Common/Storage/UserDataModel.xcdatamodeld}"
SUBSTRATE_COMPATIBILITY_ROOT="${FEARLESS_SUBSTRATE_COMPATIBILITY_MODELS_ROOT:-$ROOT_DIR/fearless/Common/Storage/SubstrateCompatibilityModels}"
USER_COMPATIBILITY_ROOT="${FEARLESS_COMPATIBILITY_MODELS_ROOT:-$ROOT_DIR/fearless/Common/Storage/CompatibilityModels}"
TOOLS_DIR="${FEARLESS_HISTORICAL_MODEL_TOOLS_DIR:-}"
COMPILER="$SCRIPT_DIR/compile-historical-store-models.sh"
EXTRACTOR="$SCRIPT_DIR/extract-historical-store-models.py"
CHECK_REPOS=0

usage() {
  cat <<'EOF'
Usage: audit-historical-store-models.sh [--repos]

Fails unless the historical Core Data store model inventory is intact:

  (a) every Source XML is the manifest's Git blob (same object id as
      `git hash-object`) and XML SHA-256, plus the conventional final LF
      when the blob has none;
  (b) every compiled .mom (freshly compiled, App and Fixtures) has the
      manifest digest and Core Data version checksum, and the App and
      Fixtures folders hold exactly the models the manifest places there;
  (c) digests are unique across the lineage, compatibility and app-bundled
      historical models, and every `matchesBundled` entry really matches;
  (d) every app-bundled entry lands on a lineage model, and Core Data's
      inferred mapping drops exactly `allowedDrops` and leaves exactly the
      `requiredConstants` attributes unsatisfied;
  (e) with --repos, every tag, TestFlight head and development commit of
      fearless-iOS, fearless-iOS-priv and shared-features-spm resolves to the
      manifest entry that lists it (extract-historical-store-models.py --verify).

Without --repos the audit works offline from this checkout alone.
EOF
}

fail() {
  echo "[historical-model-audit][error] $*" >&2
  exit 1
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --repos)
      CHECK_REPOS=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[historical-model-audit][error] unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

command -v python3 >/dev/null 2>&1 || fail "python3 is required"
command -v xcrun >/dev/null 2>&1 || fail "xcrun is required"

manifest="$FIXTURES_ROOT/manifest.json"
source_dir="$MODELS_ROOT/Source"
app_dir="$MODELS_ROOT/App/HistoricalStoreModels"
fixture_dir="$FIXTURES_ROOT/Fixtures"
[[ -s "$manifest" ]] || fail "manifest is missing: $manifest"
[[ -d "$source_dir" ]] || fail "source models are missing: $source_dir"
[[ -d "$app_dir" ]] || fail "app models folder is missing: $app_dir"
[[ -d "$fixture_dir" ]] || fail "fixture models are missing: $fixture_dir"

temporary_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/fearless-historical-model-audit.XXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT

audit_py="$temporary_dir/audit.py"
cat >"$audit_py" <<'PY'
import hashlib
import json
import os
import re
import subprocess
import sys

STORES = {"substrate": "SubstrateHistorical_", "user": "UserHistorical_"}
TIERS = {"appStore", "testFlight", "development"}
problems = []


def problem(message):
    problems.append(message)


def finish():
    if problems:
        for message in problems:
            print(f"[historical-model-audit][error] {message}", file=sys.stderr)
        sys.exit(1)


def load_manifest(path):
    try:
        with open(path, encoding="utf-8") as handle:
            manifest = json.load(handle)
    except ValueError as error:
        problem(f"manifest is not valid JSON: {error}")
        finish()
    if manifest.get("format") != "fearless.historical-store-models" or manifest.get("version") != 1:
        problem("manifest format must be fearless.historical-store-models version 1")
    if not isinstance(manifest.get("models"), list) or not manifest["models"]:
        problem("manifest lists no models")
    finish()
    return manifest


def is_hex(value, length):
    return isinstance(value, str) and re.fullmatch(f"[0-9a-f]{{{length}}}", value) is not None


def is_sorted_strings(value):
    return isinstance(value, list) and all(isinstance(v, str) for v in value) and value == sorted(set(value))


def check_entry_shape(entry):
    name = entry.get("resource", "<unnamed>")
    before = len(problems)
    store = entry.get("store")
    if store not in STORES:
        problem(f"{name}: unknown store {store!r}")
        return False
    if not is_hex(entry.get("digest"), 16):
        problem(f"{name}: digest must be 16 lowercase hex characters")
        return False
    if entry.get("resource") != STORES[store] + entry["digest"]:
        problem(f"{name}: resource must be {STORES[store]}{entry['digest']}")
    if not is_hex(entry.get("gitBlob"), 40):
        problem(f"{name}: gitBlob must be a 40-character Git object id")
    if not isinstance(entry.get("equivalentGitBlobs"), list) or \
            not all(is_hex(b, 40) for b in entry["equivalentGitBlobs"]):
        problem(f"{name}: equivalentGitBlobs must list Git object ids")
    if not is_hex(entry.get("xmlSha256"), 64):
        problem(f"{name}: xmlSha256 must be a SHA-256")
    if not isinstance(entry.get("versionChecksum"), str) or not entry["versionChecksum"]:
        problem(f"{name}: versionChecksum is missing")
    for field in ("releases", "interimTags"):
        if not isinstance(entry.get(field), list):
            problem(f"{name}: {field} must be a list")
    for field in ("heads", "developmentCommits"):
        if not isinstance(entry.get(field), list) or \
                not all(isinstance(c, dict) and is_hex(c.get("commit"), 40) for c in entry[field]):
            problem(f"{name}: {field} must list full commit ids")
    if len(problems) != before:
        return False

    if entry["releases"]:
        expected_tier = "appStore"
    elif entry["interimTags"] or entry["heads"]:
        expected_tier = "testFlight"
    elif entry["developmentCommits"]:
        expected_tier = "development"
    else:
        problem(f"{name}: no release, tag, head or development commit ships this model")
        return False
    if entry.get("tier") != expected_tier:
        problem(f"{name}: tier must be {expected_tier}, not {entry.get('tier')!r}")
    if entry.get("tier") not in TIERS:
        return False

    roles = [field for field in ("matchesBundled", "landing", "excluded") if entry.get(field) is not None]
    if len(roles) != 1:
        problem(f"{name}: exactly one of matchesBundled, landing and excluded must be set (found {roles})")
        return False
    if entry.get("landing") is not None:
        drops = entry.get("allowedDrops")
        if not isinstance(drops, dict) or set(drops) != {"entities", "attributes"} or \
                not is_sorted_strings(drops["entities"]) or not is_sorted_strings(drops["attributes"]):
            problem(f"{name}: allowedDrops must be {{entities, attributes}} with sorted names")
        constants = entry.get("requiredConstants")
        if not isinstance(constants, dict) or not all(isinstance(v, str) for v in constants.values()):
            problem(f"{name}: requiredConstants must map Entity.attribute to a string constant")
    else:
        if entry.get("allowedDrops") is not None or entry.get("requiredConstants"):
            problem(f"{name}: only app-bundled entries (with a landing) may declare allowedDrops or requiredConstants")
    return len(problems) == before


def git_blob_id(data):
    # Identical to `git hash-object --stdin` (SHA-1 object format), without needing git.
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


def listed_files(directory, suffix):
    names = set()
    for name in os.listdir(directory):
        if name == ".DS_Store":
            continue
        if not name.endswith(suffix):
            problem(f"unexpected file in {directory}: {name}")
            continue
        names.add(name[: -len(suffix)])
    return names


def provenance(manifest_path, source_dir, app_dir, fixture_dir):
    manifest = load_manifest(manifest_path)
    entries = manifest["models"]
    seen = {}
    for entry in entries:
        if not check_entry_shape(entry):
            continue
        if entry["resource"] in seen:
            problem(f"(c) digest {entry['digest']} is not unique: {entry['resource']} is listed twice")
        seen[entry["resource"]] = entry
    blobs = {}
    for entry in seen.values():
        for blob in [entry["gitBlob"]] + entry["equivalentGitBlobs"]:
            if blob in blobs:
                problem(f"Git blob {blob} is listed by {blobs[blob]} and {entry['resource']}")
            blobs[blob] = entry["resource"]
    finish()

    for resource, entry in sorted(seen.items()):
        path = os.path.join(source_dir, f"{resource}.xcdatamodel", "contents")
        if not os.path.isfile(path):
            problem(f"(a) source model missing: {path}")
            continue
        with open(path, "rb") as handle:
            data = handle.read()
        if not data.endswith(b"\n"):
            problem(f"(a) {resource} must end with the conventional final LF")
            continue
        # The file is the blob, plus one LF only when the blob has no final LF.
        candidates = [data] + ([data[:-1]] if not data[:-1].endswith(b"\n") else [])
        matched = [c for c in candidates if git_blob_id(c) == entry["gitBlob"]]
        if not matched:
            actual = " or ".join(git_blob_id(c) for c in candidates)
            problem(f"(a) {resource} Git-blob provenance changed: expected {entry['gitBlob']}, got {actual}")
            continue
        data = matched[0]
        actual_sha = hashlib.sha256(data).hexdigest()
        if actual_sha != entry["xmlSha256"]:
            problem(f"(a) {resource} XML SHA-256 changed: expected {entry['xmlSha256']}, got {actual_sha}")

    sources = set()
    for name in os.listdir(source_dir):
        if name == ".DS_Store":
            continue
        if not name.endswith(".xcdatamodel"):
            problem(f"unexpected file in {source_dir}: {name}")
            continue
        sources.add(name[: -len(".xcdatamodel")])
    for name in sorted(sources - set(seen)):
        problem(f"(a) unlisted source model: {name}")

    app_expected = {r for r, e in seen.items() if e.get("landing")}
    app_actual = listed_files(app_dir, ".mom")
    for name in sorted(app_actual - app_expected):
        problem(f"(b) unlisted app model would ship in the app: {name}")
    for name in sorted(app_expected - app_actual):
        problem(f"(b) app model missing: {name}")
    fixture_actual = listed_files(fixture_dir, ".mom")
    for name in sorted(fixture_actual - set(seen)):
        problem(f"(b) unlisted fixture model: {name}")
    for name in sorted(set(seen) - fixture_actual):
        problem(f"(b) fixture model missing: {name}")
    finish()


def run_json_lines(arguments):
    result = subprocess.run(arguments, capture_output=True)
    if result.returncode != 0:
        problem(f"{os.path.basename(arguments[0])} failed: {result.stderr.decode().strip()}")
        finish()
    return [json.loads(line) for line in result.stdout.decode().splitlines() if line.strip()]


def moms_in(directory):
    return {name[:-4]: os.path.join(directory, name) for name in sorted(os.listdir(directory)) if name.endswith(".mom")}


def models(manifest_path, generated_dir, app_dir, fixture_dir, lineage_dirs, compatibility_dirs, digest_tool, drops_tool):
    manifest = load_manifest(manifest_path)
    entries = {e["resource"]: e for e in manifest["models"]}

    lineage = {store: moms_in(directory) for store, directory in lineage_dirs.items()}
    compatibility = {store: moms_in(directory) for store, directory in compatibility_dirs.items()}
    paths = {}
    for label, directory in (("generated", generated_dir), ("app", app_dir), ("fixture", fixture_dir)):
        for name, path in moms_in(directory).items():
            paths[(label, name)] = path
    for kind, groups in (("lineage", lineage), ("compatibility", compatibility)):
        for store, moms in groups.items():
            for name, path in moms.items():
                paths[(f"{kind}:{store}", name)] = path
    by_path = {r["path"]: r for r in run_json_lines([digest_tool] + list(paths.values()))}
    record = {key: by_path[path] for key, path in paths.items()}

    # (b) compiled models carry the manifest identity.
    for resource, entry in sorted(entries.items()):
        labels = ["generated", "fixture"] + (["app"] if entry.get("landing") else [])
        for label in labels:
            actual = record.get((label, resource))
            if actual is None:
                problem(f"(b) {label} model missing: {resource}")
                continue
            if actual["digest"] != entry["digest"]:
                problem(f"(b) {label} model {resource} is stale: digest {actual['digest']}, manifest {entry['digest']}")
            if actual["versionChecksum"] != entry["versionChecksum"]:
                problem(f"(b) {label} model {resource} versionChecksum {actual['versionChecksum']} "
                        f"differs from manifest {entry['versionChecksum']}")
    finish()

    # (c) one digest per bundled model, per store.
    for store in STORES:
        bundled = {}
        for name in lineage[store]:
            bundled.setdefault(record[(f"lineage:{store}", name)]["digest"], []).append(name)
        for name in compatibility[store]:
            bundled.setdefault(record[(f"compatibility:{store}", name)]["digest"], []).append(name)
        reference = {name: digest for digest, names in bundled.items() for name in names}
        for resource, entry in entries.items():
            if entry["store"] == store and entry.get("landing"):
                bundled.setdefault(entry["digest"], []).append(resource)
        for digest, names in sorted(bundled.items()):
            if len(names) > 1:
                problem(f"(c) {store} digest {digest} is not unique across bundled models: {sorted(names)}")
        for resource, entry in sorted(entries.items()):
            if entry["store"] != store:
                continue
            matches = entry.get("matchesBundled")
            if matches is not None:
                if matches not in reference:
                    problem(f"(c) {resource} matchesBundled {matches}, which is not a bundled {store} model")
                elif reference[matches] != entry["digest"]:
                    problem(f"(c) {resource} matchesBundled {matches} but {matches} has digest {reference[matches]}")
            elif entry["digest"] in bundled and bundled[entry["digest"]] != [resource]:
                others = [n for n in bundled[entry["digest"]] if n != resource]
                problem(f"(c) {resource} duplicates bundled model {others}; record it as matchesBundled")
    finish()

    # (d) landing hops lose exactly what was reviewed.
    pairs = []
    for resource, entry in sorted(entries.items()):
        landing = entry.get("landing")
        if landing is None:
            continue
        if landing not in lineage[entry["store"]]:
            problem(f"(d) {resource} landing {landing} is not a {entry['store']} lineage model")
            continue
        pairs.append((resource, paths[("generated", resource)], lineage[entry["store"]][landing]))
    finish()
    arguments = [drops_tool]
    for _, source, destination in pairs:
        arguments += [source, destination]
    reports = {r["source"]: r for r in run_json_lines(arguments)} if pairs else {}
    for resource, source, destination in pairs:
        entry = entries[resource]
        report = reports.get(source)
        if report is None or not report.get("inferred"):
            problem(f"(d) {resource} inferred mapping to {entry['landing']} is unavailable: "
                    f"{(report or {}).get('error', 'no report')}")
            continue
        expected = entry["allowedDrops"]
        if report["droppedEntities"] != expected["entities"] or report["droppedProperties"] != expected["attributes"]:
            problem(f"(d) {resource} inferred drops differ from allowedDrops: entities {report['droppedEntities']} "
                    f"attributes {report['droppedProperties']}, allowed {expected}")
        constants = sorted(entry["requiredConstants"])
        if report["unsatisfiedRequiredAttributes"] != constants:
            problem(f"(d) {resource} unsatisfied required attributes {report['unsatisfiedRequiredAttributes']} "
                    f"differ from requiredConstants {constants}")
    finish()

    counts = {store: sum(1 for e in entries.values() if e["store"] == store) for store in STORES}
    app = sum(1 for e in entries.values() if e.get("landing"))
    print(f"[historical-model-audit] {counts['substrate']} Substrate and {counts['user']} User models; "
          f"{app} app-bundled landing hops verified")


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "provenance":
        provenance(*sys.argv[2:6])
    elif mode == "models":
        args = sys.argv[2:]
        models(args[0], args[1], args[2], args[3],
               {"substrate": args[4], "user": args[5]},
               {"substrate": args[6], "user": args[7]},
               args[8], args[9])
    finish()
PY

# (a) and folder contents first: cheap, and they fail before any compilation.
PYTHONDONTWRITEBYTECODE=1 python3 "$audit_py" provenance "$manifest" "$source_dir" "$app_dir" "$fixture_dir"

if [[ -n "$TOOLS_DIR" ]]; then
  digest_tool="$TOOLS_DIR/historical-model-digest"
  drops_tool="$TOOLS_DIR/historical-model-inferred-drops"
else
  module_cache="$temporary_dir/module-cache"
  mkdir -p "$module_cache"
  digest_tool="$temporary_dir/historical-model-digest"
  drops_tool="$temporary_dir/historical-model-inferred-drops"
  CLANG_MODULE_CACHE_PATH="$module_cache" SWIFT_MODULECACHE_PATH="$module_cache" \
    xcrun swiftc "$SCRIPT_DIR/historical-model-digest.swift" -o "$digest_tool"
  CLANG_MODULE_CACHE_PATH="$module_cache" SWIFT_MODULECACHE_PATH="$module_cache" \
    xcrun swiftc "$SCRIPT_DIR/historical-model-inferred-drops.swift" -o "$drops_tool"
fi
[[ -x "$digest_tool" && -x "$drops_tool" ]] || fail "model inspection tools are unavailable"

FEARLESS_HISTORICAL_STORE_MODELS_ROOT="$MODELS_ROOT" \
  FEARLESS_HISTORICAL_STORE_MODEL_FIXTURES_ROOT="$FIXTURES_ROOT" \
  "$COMPILER" --output-dir "$temporary_dir/generated" >/dev/null ||
  fail "historical source models do not compile"

sdk_root="$(xcrun --sdk iphoneos --show-sdk-path)"
for lineage in "substrate|$SUBSTRATE_LINEAGE_ROOT" "user|$USER_LINEAGE_ROOT"; do
  xcrun momc \
    --sdkroot="$sdk_root" \
    --iphoneos-deployment-target 14.1 \
    --module fearless \
    --no-warnings \
    "${lineage#*|}" \
    "$temporary_dir/${lineage%%|*}.momd" >"$temporary_dir/${lineage%%|*}-momc.log" 2>&1 || {
    cat "$temporary_dir/${lineage%%|*}-momc.log" >&2
    fail "lineage models do not compile: ${lineage#*|}"
  }
done

PYTHONDONTWRITEBYTECODE=1 python3 "$audit_py" models \
  "$manifest" \
  "$temporary_dir/generated/Fixtures" \
  "$app_dir" \
  "$fixture_dir" \
  "$temporary_dir/substrate.momd" \
  "$temporary_dir/user.momd" \
  "$SUBSTRATE_COMPATIBILITY_ROOT/Compiled" \
  "$USER_COMPATIBILITY_ROOT/Compiled" \
  "$digest_tool" \
  "$drops_tool"

if [[ "$CHECK_REPOS" -eq 1 ]]; then
  PYTHONDONTWRITEBYTECODE=1 python3 "$EXTRACTOR" --verify --manifest "$manifest"
fi

echo "[historical-model-audit] PASS"
