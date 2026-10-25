#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MODELS_ROOT="${FEARLESS_HISTORICAL_STORE_MODELS_ROOT:-$ROOT_DIR/fearless/Common/Storage/HistoricalStoreModels}"
FIXTURES_ROOT="${FEARLESS_HISTORICAL_STORE_MODEL_FIXTURES_ROOT:-$ROOT_DIR/fearlessTests/Resources/HistoricalStoreModels}"
DEPLOYMENT_TARGET="${FEARLESS_HISTORICAL_STORE_MODELS_DEPLOYMENT_TARGET:-14.1}"
SOURCE_DIR="$MODELS_ROOT/Source"
MANIFEST="$FIXTURES_ROOT/manifest.json"
APP_OUTPUT_DIR="$MODELS_ROOT/App/HistoricalStoreModels"
FIXTURE_OUTPUT_DIR="$FIXTURES_ROOT/Fixtures"
FLAT_OUTPUT_DIR=""
# Optional: reuse compiled models by source hash (the audit's own test suite sets it).
CACHE_DIR="${FEARLESS_HISTORICAL_STORE_MODELS_COMPILE_CACHE:-}"

usage() {
  cat <<'EOF'
Usage: compile-historical-store-models.sh [--output-dir PATH]
       compile-historical-store-models.sh --source-dir PATH --flat-output-dir PATH

Compiles the verbatim historical Core Data store models with Xcode's model
compiler, using the production flags (--module fearless, deployment target
14.1), as compile-substrate-storage-compatibility-models.sh does.

By default every model in the manifest is written to the test-only
fearlessTests/Resources/HistoricalStoreModels/Fixtures, and the models the app
must recognise (manifest entries with a landing) also to
fearless/Common/Storage/HistoricalStoreModels/App/HistoricalStoreModels, the
folder the app bundles as HistoricalStoreModels/.

  --output-dir PATH       write PATH/App and PATH/Fixtures instead
  --source-dir PATH       compile every PATH/<name>.xcdatamodel ...
  --flat-output-dir PATH  ... into PATH/<name>.mom, without a manifest

Environment:
  FEARLESS_HISTORICAL_STORE_MODELS_ROOT          Source/ and App/ root
  FEARLESS_HISTORICAL_STORE_MODEL_FIXTURES_ROOT  manifest.json and Fixtures/ root
  FEARLESS_HISTORICAL_STORE_MODELS_COMPILE_CACHE reuse compiled models by source hash
EOF
}

fail() {
  echo "[historical-model-compile][error] $*" >&2
  exit "${2:-1}"
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --output-dir)
      [[ "$#" -ge 2 ]] || fail "--output-dir requires a path" 64
      APP_OUTPUT_DIR="$2/App"
      FIXTURE_OUTPUT_DIR="$2/Fixtures"
      shift 2
      ;;
    --source-dir)
      [[ "$#" -ge 2 ]] || fail "--source-dir requires a path" 64
      SOURCE_DIR="$2"
      shift 2
      ;;
    --flat-output-dir)
      [[ "$#" -ge 2 ]] || fail "--flat-output-dir requires a path" 64
      FLAT_OUTPUT_DIR="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[historical-model-compile][error] unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

command -v xcrun >/dev/null 2>&1 || fail "xcrun is required" 69
[[ -d "$SOURCE_DIR" ]] || fail "source directory missing: $SOURCE_DIR" 66

sdk_root="$(xcrun --sdk iphoneos --show-sdk-path)"
cache_salt="$(printf '%s %s' "$sdk_root" "$DEPLOYMENT_TARGET" | shasum -a 256 | cut -c1-16)"
[[ -z "$CACHE_DIR" ]] || mkdir -p "$CACHE_DIR"
temporary_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/fearless-historical-models.XXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT

compile_model() {
  local model_name="$1"
  local source_path="$SOURCE_DIR/$model_name.xcdatamodel"
  local output_path="$temporary_dir/$model_name.mom"
  local cache_path=""

  [[ -s "$source_path/contents" ]] || {
    echo "[historical-model-compile][error] source model missing: $source_path/contents" >&2
    return 66
  }
  if [[ -n "$CACHE_DIR" ]]; then
    cache_path="$CACHE_DIR/$(shasum -a 256 "$source_path/contents" | awk '{print $1}')-$cache_salt.mom"
    if [[ -s "$cache_path" ]]; then
      cp "$cache_path" "$output_path"
      return 0
    fi
  fi
  xcrun momc \
    --sdkroot="$sdk_root" \
    --iphoneos-deployment-target "$DEPLOYMENT_TARGET" \
    --module fearless \
    --no-warnings \
    "$source_path" \
    "$output_path" >/dev/null || {
    echo "[historical-model-compile][error] momc failed: $model_name" >&2
    return 65
  }
  [[ -s "$output_path" ]] || {
    echo "[historical-model-compile][error] momc produced an empty model: $model_name" >&2
    return 65
  }
  if [[ -n "$cache_path" ]]; then
    cp "$output_path" "$cache_path.$$" && mv "$cache_path.$$" "$cache_path"
  fi
}

# momc takes about a second per model; compile in parallel batches.
compile_models() {
  local jobs pids=() model_name pid status=0
  jobs="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
  for model_name in "$@"; do
    compile_model "$model_name" &
    pids+=("$!")
    if [[ "${#pids[@]}" -ge "$jobs" ]]; then
      for pid in "${pids[@]}"; do wait "$pid" || status=$?; done
      pids=()
    fi
  done
  for pid in ${pids[@]+"${pids[@]}"}; do wait "$pid" || status=$?; done
  [[ "$status" -eq 0 ]] || fail "compilation failed" "$status"
}

install_models() {
  local output_dir="$1"
  shift
  local model_name

  mkdir -p "$output_dir"
  find "$output_dir" -maxdepth 1 -name '*.mom' -type f -delete
  for model_name in "$@"; do
    cp "$temporary_dir/$model_name.mom" "$output_dir/$model_name.mom"
    chmod 0644 "$output_dir/$model_name.mom"
  done
}

if [[ -n "$FLAT_OUTPUT_DIR" ]]; then
  model_names=()
  for source_path in "$SOURCE_DIR"/*.xcdatamodel; do
    [[ -d "$source_path" ]] || continue
    model_names+=("$(basename "$source_path" .xcdatamodel)")
  done
  [[ "${#model_names[@]}" -gt 0 ]] || fail "no models in $SOURCE_DIR" 66
  compile_models "${model_names[@]}"
  mkdir -p "$FLAT_OUTPUT_DIR"
  for model_name in "${model_names[@]}"; do
    cp "$temporary_dir/$model_name.mom" "$FLAT_OUTPUT_DIR/$model_name.mom"
  done
  echo "[historical-model-compile] Compiled ${#model_names[@]} models into $FLAT_OUTPUT_DIR"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || fail "python3 is required" 69
[[ -s "$MANIFEST" ]] || fail "manifest missing: $MANIFEST" 66

# One line per model: "<resource> <app|fixture>".
model_list="$(python3 - "$MANIFEST" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    manifest = json.load(handle)
for entry in manifest["models"]:
    print(entry["resource"], "app" if entry.get("landing") else "fixture")
PY
)" || fail "manifest is not readable: $MANIFEST"

all_models=()
app_models=()
while read -r resource placement; do
  [[ -n "$resource" ]] || continue
  all_models+=("$resource")
  [[ "$placement" == "app" ]] && app_models+=("$resource")
done <<<"$model_list"

[[ "${#all_models[@]}" -gt 0 ]] || fail "manifest lists no models" 65
compile_models "${all_models[@]}"

install_models "$FIXTURE_OUTPUT_DIR" "${all_models[@]}"
install_models "$APP_OUTPUT_DIR" ${app_models[@]+"${app_models[@]}"}

echo "[historical-model-compile] Compiled ${#all_models[@]} fixtures into $FIXTURE_OUTPUT_DIR"
echo "[historical-model-compile] Copied ${#app_models[@]} app models into $APP_OUTPUT_DIR"
