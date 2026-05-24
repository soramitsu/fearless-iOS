#!/usr/bin/env bash
set -euo pipefail

# Validates environment-backed runtime keys used by CIKeys.swift.
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
  SUBSCAN_API_KEY
  SORA_CARD_API_KEY
  SORA_CARD_DOMAIN
  SORA_CARD_KYC_ENDPOINT_URL
  SORA_CARD_KYC_USERNAME
  SORA_CARD_KYC_PASSWORD
  PAY_WINGS_REPOSITORY_URL
  PAY_WINGS_USERNAME
  PAY_WINGS_PASSWORD
  X1_ENDPOINT_URL_RELEASE
  X1_WIDGET_ID_RELEASE
  X1_ENDPOINT_URL_DEBUG
  X1_WIDGET_ID_DEBUG
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
  COINBASE_APP_ID
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
for key in "${keys[@]}"; do
  if [[ -z "${!key:-}" ]]; then
    missing+=("$key")
  fi
done

if ((${#missing[@]})); then
  echo "[runtime-keys] Missing ${#missing[@]} key(s):"
  printf '  %s\n' "${missing[@]}"
  if [[ "$STRICT_RUNTIME_KEYS" == "1" ]]; then
    exit 1
  fi
  echo "[runtime-keys] WARN: missing keys are allowed in non-strict mode; affected API-backed features may be disabled."
else
  echo "[runtime-keys] OK: all runtime keys are present"
fi
