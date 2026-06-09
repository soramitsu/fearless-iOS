#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="${1:-$(pwd)}"

fail() {
  echo "[check-runtime-key-contracts] $1" >&2
  exit 1
}

ensure_file() {
  local file="$1"

  [[ -f "$file" ]] || fail "Missing file: $file"
}

compare_sets() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  local diff_output
  diff_output="$(comm -3 "$expected" "$actual" || true)"

  if [[ -n "$diff_output" ]]; then
    echo "[check-runtime-key-contracts] ${label} mismatch:" >&2
    echo "$diff_output" >&2
    exit 1
  fi
}

require_line() {
  local file="$1"
  local pattern="$2"
  local description="$3"

  grep -Fq "$pattern" "$file" ||
    fail "Missing ${description}"
}

require_exact_line() {
  local file="$1"
  local expected_line="$2"
  local description="$3"

  grep -Fxq "$expected_line" "$file" ||
    fail "Missing ${description}"
}

generator_file="$ROOT/Packages/FearlessBuildTools/Sources/CIKeysGeneratorCore/CIKeysGenerator.swift"
stencil_file="$ROOT/fearless/CIKeys.stencil"
env_example="$ROOT/.env.example"
runtime_validator="$ROOT/scripts/secrets/validate-runtime-keys.sh"
codecov_workflow="$ROOT/.github/workflows/codecov.yml"
archive_smoke="$ROOT/scripts/ci/archive-smoke.sh"

ensure_file "$generator_file"
ensure_file "$stencil_file"
ensure_file "$env_example"
ensure_file "$runtime_validator"
ensure_file "$codecov_workflow"
ensure_file "$archive_smoke"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

generator_args="$tmpdir/generator-args"
stencil_args="$tmpdir/stencil-args"
generator_env_keys="$tmpdir/generator-env-keys"
env_example_keys="$tmpdir/env-example-keys"
validator_keys="$tmpdir/validator-keys"
codecov_runtime_keys="$tmpdir/codecov-runtime-keys"
generator_fallback_pairs="$tmpdir/generator-fallback-pairs"
validator_fallback_pairs="$tmpdir/validator-fallback-pairs"

perl -ne 'while (/"([A-Za-z0-9_]+)":\s*\.init\(/g) { print "$1\n" }' "$generator_file" |
  sort -u >"$generator_args"

perl -ne 'while (/\{\{\s*argument\.([A-Za-z0-9_]+)\s*\}\}/g) { print "$1\n" }' "$stencil_file" |
  sort -u >"$stencil_args"

perl -ne '
  while (/key:\s*"([A-Z0-9_]+)"/g) { print "$1\n" }
  while (/fallbackKey:\s*"([A-Z0-9_]+)"/g) { print "$1\n" }
' "$generator_file" | sort -u >"$generator_env_keys"

perl -0ne '
  while (/"[A-Za-z0-9_]+":\s*\.init\(\s*key:\s*"([A-Z0-9_]+)"\s*,\s*fallbackKey:\s*"([A-Z0-9_]+)"\s*\)/sg) {
    print "$1 $2\n";
  }
' "$generator_file" | sort -u >"$generator_fallback_pairs"

awk -F= '/^[A-Z0-9_]+=/{print $1}' "$env_example" |
  sort -u >"$env_example_keys"

awk '
  /^keys=\(/ { in_keys = 1; next }
  in_keys && /^\)/ { in_keys = 0; next }
  in_keys {
    for (i = 1; i <= NF; i++) {
      if ($i ~ /^[A-Z0-9_]+$/) {
        print $i
      }
    }
  }
' "$runtime_validator" | sort -u >"$validator_keys"

perl -0ne '
  if (/fallback_key_for\(\)\s*\{(.*?)\n\}/s) {
    $body = $1;
    while ($body =~ /^\s*([A-Z0-9_]+)\)\s*\n\s*echo "([A-Z0-9_]+)"/mg) {
      print "$1 $2\n";
    }
  }
' "$runtime_validator" | sort -u >"$validator_fallback_pairs"

perl -ne '
  while (/\$\{\{\s*secrets\.([A-Z0-9_]+)\s*\}\}/g) {
    $key = $1;
    next if $key =~ /^(GH_READ_TOKEN|IOS_DISTRIBUTION_CERTIFICATE_P12_BASE64|IOS_DISTRIBUTION_CERTIFICATE_PASSWORD|FEARLESSWALLET_DEV_ADHOC_PROFILE_BASE64|APP_STORE_CONNECT_API_KEY_CONTENT|APP_STORE_CONNECT_API_KEY_ID|APP_STORE_CONNECT_API_KEY_ISSUER_ID)$/;
    print "$key\n";
  }
' "$codecov_workflow" | sort -u >"$codecov_runtime_keys"

compare_sets "$generator_args" "$stencil_args" "CI key generator arguments vs stencil placeholders"
compare_sets "$generator_env_keys" "$env_example_keys" "CI key generator environment keys vs .env.example"
compare_sets "$generator_env_keys" "$validator_keys" "CI key generator environment keys vs runtime validator"
compare_sets "$generator_env_keys" "$codecov_runtime_keys" "CI key generator environment keys vs Codecov workflow runtime secrets"
compare_sets "$generator_fallback_pairs" "$validator_fallback_pairs" "CI key generator fallbacks vs runtime validator fallbacks"

require_line "$archive_smoke" 'RUNTIME_ENV_FILE="${ENV_FILE:-}"' "archive-smoke runtime env file configuration"
require_line "$archive_smoke" 'load_runtime_env_file()' "archive-smoke runtime env file loader"
require_line "$archive_smoke" 'source "$RUNTIME_ENV_FILE"' "archive-smoke runtime env file sourcing"
require_exact_line "$archive_smoke" 'load_runtime_env_file' "archive-smoke runtime env file load call"

set +e
signed_archive_runtime_check="$(
  cd "$ROOT" &&
    env -i \
      HOME="$HOME" \
      PATH="${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}" \
      REQUIRE_SIGNED_ARCHIVE=0 \
      SIGNED_ARCHIVE=1 \
      SKIP_BOOTSTRAP=1 \
      ENV_FILE=/dev/null \
      bash "$archive_smoke" "$ROOT" 2>&1
)"
signed_archive_runtime_status=$?
set -e

if [[ "$signed_archive_runtime_status" != "2" ]]; then
  echo "[check-runtime-key-contracts] signed archive runtime-key preflight returned ${signed_archive_runtime_status}, expected 2" >&2
  echo "$signed_archive_runtime_check" >&2
  exit 1
fi

if ! grep -Fq "[runtime-keys] Missing" <<<"$signed_archive_runtime_check"; then
  echo "[check-runtime-key-contracts] SIGNED_ARCHIVE=1 must require strict runtime keys by default" >&2
  echo "$signed_archive_runtime_check" >&2
  exit 1
fi

echo "[check-runtime-key-contracts] OK"
