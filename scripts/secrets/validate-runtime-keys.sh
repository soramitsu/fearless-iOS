#!/usr/bin/env bash
set -euo pipefail

# Validates environment-backed keys used to generate CIKeys.generated.swift.
#
# Usage:
#   scripts/secrets/validate-runtime-keys.sh
#   ENV_FILE=.env.local scripts/secrets/validate-runtime-keys.sh
#   STRICT_RUNTIME_KEYS=1 scripts/secrets/validate-runtime-keys.sh

ROOT="${1:-$(pwd)}"
ENV_FILE="${ENV_FILE:-}"
STRICT_RUNTIME_KEYS="${STRICT_RUNTIME_KEYS:-0}"

if [[ -z "$ENV_FILE" ]]; then
  if [[ -f "$ROOT/.env.local" ]]; then
    ENV_FILE="$ROOT/.env.local"
  elif [[ -f "$ROOT/.env" ]]; then
    ENV_FILE="$ROOT/.env"
  fi
fi

if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

keys=(
  MOONPAY_PRODUCTION_SECRET
  MOONPAY_TEST_SECRET
  SORA_CARD_API_KEY
  SORA_CARD_DOMAIN
  SORA_CARD_KYC_ENDPOINT_URL
  SORA_CARD_KYC_USERNAME
  SORA_CARD_KYC_PASSWORD
  RAMP_HOST_API_KEY
  MOONBEAM_CROWDLOAN_DEV_API_KEY
  MOONBEAM_CROWDLOAN_PROD_API_KEY
  FL_BLAST_API_ETHEREUM_KEY
  FL_BLAST_API_BSC_KEY
  FL_BLAST_API_SEPOLIA_KEY
  FL_BLAST_API_GOERLI_KEY
  FL_BLAST_API_POLYGON_KEY
  FL_BLAST_API_ETHEREUM_KEY_DEBUG
  FL_BLAST_API_BSC_KEY_DEBUG
  FL_BLAST_API_SEPOLIA_KEY_DEBUG
  FL_BLAST_API_GOERLI_KEY_DEBUG
  FL_BLAST_API_POLYGON_KEY_DEBUG
  WEB_CLIENT_ID_RELEASE
  FEARLESS_GOOGLE_URL_SCHEME_RELEASE
  WEB_CLIENT_ID_DEBUG
  FEARLESS_GOOGLE_URL_SCHEME_DEBUG
  FL_WALLET_CONNECT_PROJECT_ID
  FL_WALLET_CONNECT_PROJECT_ID_DEBUG
  FL_IOS_ETHERSCAN_API_KEY
  FL_IOS_POLYGONSCAN_API_KEY
  FL_IOS_BSCSCAN_API_KEY
  FL_OKLINK_API_KEY
  FL_IOS_OPTIMISTIC_ETHERSCAN_API_KEY
  FL_IOS_ALCHEMY_API_ETHEREUM_KEY
  FL_DWELLIR_API_KEY
  COINBASE_SESSION_TOKEN
  FL_TON_API_KEY
  FL_TON_API_KEY_DEBUG
  FL_OKX_API_KEY
  FL_OKX_SECRET_KEY
  FL_OKX_PASSPHRASE
  FL_OKX_PROJECT_ID
  FL_NOMIS_CLIENT_ID
  FL_NOMIS_API_KEY
)

missing=()
placeholders=()

is_placeholder_value() {
  local value="$1"
  local trimmed
  local normalized

  trimmed="$(printf '%s' "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  normalized="$(printf '%s' "$trimmed" | tr '[:upper:]' '[:lower:]')"

  case "$normalized" in
    todo|tbd|changeme|change_me|replace_me|replaceme|placeholder|dummy|example|example.*|http://example.*|https://example.*|*.example.*|"<"*">"|"your_"*|"your-"*)
      return 0
      ;;
  esac

  return 1
}

fallback_key_for() {
  case "$1" in
    FL_BLAST_API_ETHEREUM_KEY_DEBUG)
      echo "FL_BLAST_API_ETHEREUM_KEY"
      ;;
    FL_BLAST_API_BSC_KEY_DEBUG)
      echo "FL_BLAST_API_BSC_KEY"
      ;;
    FL_BLAST_API_SEPOLIA_KEY_DEBUG)
      echo "FL_BLAST_API_SEPOLIA_KEY"
      ;;
    FL_BLAST_API_GOERLI_KEY_DEBUG)
      echo "FL_BLAST_API_GOERLI_KEY"
      ;;
    FL_BLAST_API_POLYGON_KEY_DEBUG)
      echo "FL_BLAST_API_POLYGON_KEY"
      ;;
    WEB_CLIENT_ID_DEBUG)
      echo "WEB_CLIENT_ID_RELEASE"
      ;;
    FEARLESS_GOOGLE_URL_SCHEME_DEBUG)
      echo "FEARLESS_GOOGLE_URL_SCHEME_RELEASE"
      ;;
    FL_WALLET_CONNECT_PROJECT_ID_DEBUG)
      echo "FL_WALLET_CONNECT_PROJECT_ID"
      ;;
    FL_TON_API_KEY_DEBUG)
      echo "FL_TON_API_KEY"
      ;;
    *)
      return 1
      ;;
  esac
}

has_valid_value() {
  local value="$1"
  local trimmed_value

  trimmed_value="$(printf '%s' "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [[ -n "$trimmed_value" ]] && ! is_placeholder_value "$value"
}

key_is_required() {
  local expected_key="$1"
  local key

  for key in "${keys[@]}"; do
    if [[ "$key" == "$expected_key" ]]; then
      return 0
    fi
  done

  return 1
}

for key in "${keys[@]}"; do
  value="${!key:-}"
  trimmed_value="$(printf '%s' "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

  if [[ -z "$trimmed_value" ]]; then
    fallback_key="$(fallback_key_for "$key" || true)"

    if [[ -n "$fallback_key" ]] && has_valid_value "${!fallback_key:-}"; then
      continue
    fi

    if [[ -n "$fallback_key" ]] && key_is_required "$fallback_key"; then
      continue
    fi

    missing+=("$key")
  elif is_placeholder_value "$value"; then
    placeholders+=("$key")
  fi
done

if ((${#missing[@]})); then
  echo "[runtime-keys] Missing ${#missing[@]} key(s):"
  printf '  %s\n' "${missing[@]}"
fi

if ((${#placeholders[@]})); then
  echo "[runtime-keys] Placeholder ${#placeholders[@]} key(s):"
  printf '  %s\n' "${placeholders[@]}"
fi

if ((${#missing[@]} || ${#placeholders[@]})); then
  if [[ "$STRICT_RUNTIME_KEYS" == "1" ]]; then
    exit 1
  fi
  echo "[runtime-keys] WARN: invalid keys are allowed in non-strict mode; affected API-backed features may be disabled."
else
  echo "[runtime-keys] OK: all runtime keys are present"
fi
