#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MODELS_ROOT="${FEARLESS_COMPATIBILITY_MODELS_ROOT:-$ROOT_DIR/fearless/Common/Storage/CompatibilityModels}"
SOURCE_DIR="$MODELS_ROOT/Source"
OUTPUT_DIR="$MODELS_ROOT/Compiled"
DEPLOYMENT_TARGET="${FEARLESS_COMPATIBILITY_MODELS_DEPLOYMENT_TARGET:-14.1}"

usage() {
  cat <<'EOF'
Usage: compile-user-storage-compatibility-models.sh [--output-dir PATH]

Compiles the repo-owned user-storage compatibility models with Xcode's Core
Data model compiler. The default output is the checked-in Compiled directory.

Environment:
  FEARLESS_COMPATIBILITY_MODELS_ROOT
      Override the CompatibilityModels root (used by adversarial tests).
  FEARLESS_COMPATIBILITY_MODELS_DEPLOYMENT_TARGET
      Override the iOS deployment target passed to momc (default: 14.1).
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --output-dir)
      [[ "$#" -ge 2 ]] || {
        echo "[user-storage-model-compile][error] --output-dir requires a path" >&2
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
      echo "[user-storage-model-compile][error] unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

command -v xcrun >/dev/null 2>&1 || {
  echo "[user-storage-model-compile][error] xcrun is required" >&2
  exit 69
}

model_names=(
  "LegacyEcosystemUserDataModel_v12"
  "CompatibleUserDataModel_v13"
)

for model_name in "${model_names[@]}"; do
  source_path="$SOURCE_DIR/$model_name.xcdatamodel"
  [[ -f "$source_path/contents" ]] || {
    echo "[user-storage-model-compile][error] source model missing: $source_path/contents" >&2
    exit 66
  }
done

sdk_root="$(xcrun --sdk iphoneos --show-sdk-path)"
temporary_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/fearless-user-storage-models.XXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT

for model_name in "${model_names[@]}"; do
  xcrun momc \
    --sdkroot="$sdk_root" \
    --iphoneos-deployment-target "$DEPLOYMENT_TARGET" \
    --no-warnings \
    "$SOURCE_DIR/$model_name.xcdatamodel" \
    "$temporary_dir/$model_name.mom"

  [[ -s "$temporary_dir/$model_name.mom" ]] || {
    echo "[user-storage-model-compile][error] momc produced an empty model: $model_name" >&2
    exit 65
  }
done

mkdir -p "$OUTPUT_DIR"
for model_name in "${model_names[@]}"; do
  cp "$temporary_dir/$model_name.mom" "$OUTPUT_DIR/$model_name.mom"
  chmod 0644 "$OUTPUT_DIR/$model_name.mom"
done

echo "[user-storage-model-compile] Compiled ${#model_names[@]} models into $OUTPUT_DIR"
