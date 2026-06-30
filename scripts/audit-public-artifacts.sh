#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "$ROOT_DIR"

fail() {
  printf 'Public artifact audit failed: %s\n' "$1" >&2
  exit 1
}

tracked_files="$(mktemp)"
tmp_matches="$(mktemp)"
trap 'rm -f "$tracked_files" "$tmp_matches"' EXIT

git ls-files > "$tracked_files"

if grep -E '(^|/)(DerivedData|build)(/|$)|\.(xcarchive|ipa|dSYM\.zip)$' "$tracked_files" > "$tmp_matches"; then
  cat "$tmp_matches" >&2
  fail 'generated iOS build output is tracked'
fi

if grep -E '(GoogleService-Info\.plist$|\.mobileprovision$|\.p12$|\.p8$|\.pem$|\.cer$|\.der$|\.key$)' "$tracked_files" > "$tmp_matches"; then
  cat "$tmp_matches" >&2
  fail 'signing material, Firebase config, or private key artifacts are tracked'
fi

if grep -E '(^|/)\.env($|\.|/)' "$tracked_files" | grep -Ev '^\.env\.example$' > "$tmp_matches"; then
  cat "$tmp_matches" >&2
  fail 'unexpected env file is tracked'
fi

if git grep -n -I -E -- '-----BEGIN (RSA |DSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----|AIza[0-9A-Za-z_-]{35}|[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com' -- . ':!Podfile.lock' ':!*.xcmappingmodel/*' > "$tmp_matches"; then
  cat "$tmp_matches" >&2
  fail 'tracked content contains private key material, Google API keys, or OAuth client IDs'
fi

if [[ -f fearless/CIKeys.stencil ]]; then
  if grep -nE 'static var [A-Za-z0-9_]+: String = "[^"{]' fearless/CIKeys.stencil > "$tmp_matches"; then
    cat "$tmp_matches" >&2
    fail 'CIKeys.stencil contains a non-placeholder string value'
  fi
fi

printf 'Public artifact audit passed.\n'
