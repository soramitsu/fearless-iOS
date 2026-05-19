#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
LOG_PREFIX="${2:-[restore-swiftpm-contract-files]}"

workspace_swiftpm_dir="$ROOT/fearless.xcworkspace/xcshareddata/swiftpm"
project_swiftpm_dir="$ROOT/fearless.xcodeproj/project.xcworkspace/xcshareddata/swiftpm"
workspace_resolved="$workspace_swiftpm_dir/Package.resolved"
project_resolved="$project_swiftpm_dir/Package.resolved"
mirrors_reference="$ROOT/scripts/deps/mirrors.json"
workspace_mirrors_dir="$workspace_swiftpm_dir/configuration"
project_mirrors_dir="$project_swiftpm_dir/configuration"
workspace_mirrors="$workspace_mirrors_dir/mirrors.json"
project_mirrors="$project_mirrors_dir/mirrors.json"

mkdir -p "$workspace_swiftpm_dir" "$project_swiftpm_dir" "$workspace_mirrors_dir" "$project_mirrors_dir"

if [[ ! -f "$workspace_resolved" && -f "$project_resolved" ]]; then
  cp "$project_resolved" "$workspace_resolved"
  echo "${LOG_PREFIX} Restored workspace Package.resolved from project copy"
elif [[ ! -f "$project_resolved" && -f "$workspace_resolved" ]]; then
  cp "$workspace_resolved" "$project_resolved"
  echo "${LOG_PREFIX} Restored project Package.resolved from workspace copy"
fi

if [[ -f "$mirrors_reference" ]]; then
  if [[ ! -f "$workspace_mirrors" ]]; then
    cp "$mirrors_reference" "$workspace_mirrors"
    echo "${LOG_PREFIX} Restored workspace SwiftPM mirrors config"
  fi
  if [[ ! -f "$project_mirrors" ]]; then
    cp "$mirrors_reference" "$project_mirrors"
    echo "${LOG_PREFIX} Restored project SwiftPM mirrors config"
  fi
fi
