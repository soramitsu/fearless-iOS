#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
REFERENCE_MIRRORS="$ROOT/scripts/deps/mirrors.json"
LOCAL_CONFIG_DIR="$ROOT/SourcePackages/configuration"
LOCAL_MIRRORS="$LOCAL_CONFIG_DIR/mirrors.json"
LOCAL_GIT_CONFIG="$LOCAL_CONFIG_DIR/gitconfig"

if [[ ! -f "$REFERENCE_MIRRORS" ]]; then
  echo "[bootstrap-local-swiftpm-config] Missing reference mirrors file: $REFERENCE_MIRRORS" >&2
  exit 1
fi

mkdir -p "$LOCAL_CONFIG_DIR"
: > "$LOCAL_GIT_CONFIG"

if [[ -f "$HOME/.gitconfig" ]]; then
  git config --file "$LOCAL_GIT_CONFIG" include.path "$HOME/.gitconfig"
fi

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

write_mirror_entry() {
  local original="$1"
  local mirror="$2"
  local prefix="${3:-}"

  printf '%s{\n' "$prefix"
  printf '      "mirror" : "%s",\n' "$(json_escape "$mirror")"
  printf '      "original" : "%s"\n' "$(json_escape "$original")"
  printf '    }'
}

add_git_mirror() {
  local original="$1"
  local mirror="$2"

  if git -C "$mirror" rev-parse --is-bare-repository >/dev/null 2>&1; then
    git config --file "$LOCAL_GIT_CONFIG" "url.${mirror}.insteadOf" "$original"
  fi
}

{
  printf '{\n'
  printf '  "object" : [\n'
  write_mirror_entry \
    "https://github.com/bnsports/Web3.swift.git" \
    "https://github.com/soramitsu/web3-swift" \
    "    "

  for spec in \
    "https://github.com/soramitsu/shared-features-spm.git|$ROOT/SourcePackages/repositories/shared-features-spm-6a339796" \
    "https://github.com/DRadmir/ton-api-swift.git|$ROOT/SourcePackages/repositories/ton-api-swift-6829fcd7" \
    "https://github.com/DRadmir/ton-swift.git|$ROOT/SourcePackages/repositories/ton-swift-9bcb2fd0"
  do
    original="${spec%%|*}"
    mirror="${spec#*|}"

    if git -C "$mirror" rev-parse --is-bare-repository >/dev/null 2>&1; then
      printf ',\n'
      write_mirror_entry "$original" "$mirror" "    "
    fi
  done

  printf '\n'
  printf '  ],\n'
  printf '  "version" : 1\n'
  printf '}\n'
} > "$LOCAL_MIRRORS"

add_git_mirror \
  "https://github.com/soramitsu/shared-features-spm.git" \
  "$ROOT/SourcePackages/repositories/shared-features-spm-6a339796"
add_git_mirror \
  "https://github.com/DRadmir/ton-api-swift.git" \
  "$ROOT/SourcePackages/repositories/ton-api-swift-6829fcd7"
add_git_mirror \
  "https://github.com/DRadmir/ton-swift.git" \
  "$ROOT/SourcePackages/repositories/ton-swift-9bcb2fd0"

echo "[bootstrap-local-swiftpm-config] Bootstrapped local mirrors config"
echo "[bootstrap-local-swiftpm-config] Source: $REFERENCE_MIRRORS"
echo "[bootstrap-local-swiftpm-config] Target: $LOCAL_MIRRORS"
echo "[bootstrap-local-swiftpm-config] Git config: $LOCAL_GIT_CONFIG"
