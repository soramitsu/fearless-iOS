#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MODELS_ROOT="${FEARLESS_SUBSTRATE_COMPATIBILITY_MODELS_ROOT:-$ROOT_DIR/fearless/Common/Storage/SubstrateCompatibilityModels}"
SOURCE_DIR="$MODELS_ROOT/Source"
OUTPUT_DIR="$MODELS_ROOT/Compiled"
DEPLOYMENT_TARGET="${FEARLESS_SUBSTRATE_COMPATIBILITY_MODELS_DEPLOYMENT_TARGET:-14.1}"

usage() {
  cat <<'EOF'
Usage: compile-substrate-storage-compatibility-models.sh [--output-dir PATH]

Compiles the immutable public-App-Store Substrate compatibility models with
Xcode's Core Data model compiler. The default output is the checked-in
Compiled directory.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --output-dir)
      [[ "$#" -ge 2 ]] || {
        echo "[substrate-model-compile][error] --output-dir requires a path" >&2
        exit 64
      }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[substrate-model-compile][error] unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

command -v xcrun >/dev/null 2>&1 || {
  echo "[substrate-model-compile][error] xcrun is required" >&2
  exit 69
}

model_names=(
  "LegacyPublicSubstrateDataModel_v8"
  "LegacyPublicSubstrateDataModel_v9"
)

for model_name in "${model_names[@]}"; do
  source_path="$SOURCE_DIR/$model_name.xcdatamodel/contents"
  [[ -s "$source_path" ]] || {
    echo "[substrate-model-compile][error] source model missing: $source_path" >&2
    exit 66
  }
done

sdk_root="$(xcrun --sdk iphoneos --show-sdk-path)"
temporary_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/fearless-substrate-models.XXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT

for model_name in "${model_names[@]}"; do
  xcrun momc \
    --sdkroot="$sdk_root" \
    --iphoneos-deployment-target "$DEPLOYMENT_TARGET" \
    --module fearless \
    --no-warnings \
    "$SOURCE_DIR/$model_name.xcdatamodel" \
    "$temporary_dir/$model_name.mom"

  [[ -s "$temporary_dir/$model_name.mom" ]] || {
    echo "[substrate-model-compile][error] momc produced an empty model: $model_name" >&2
    exit 65
  }
done

mkdir -p "$OUTPUT_DIR"
for model_name in "${model_names[@]}"; do
  cp "$temporary_dir/$model_name.mom" "$OUTPUT_DIR/$model_name.mom"
  chmod 0644 "$OUTPUT_DIR/$model_name.mom"
done

echo "[substrate-model-compile] Compiled ${#model_names[@]} models into $OUTPUT_DIR"
