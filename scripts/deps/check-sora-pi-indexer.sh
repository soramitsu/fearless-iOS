#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
CHAINS_JSON="$ROOT/fearless/Modules/LiquidityPools/LiquidityPoolDetails/Resources/chains.json"
CHAIN_SYNC_SERVICE="$ROOT/fearless/Common/Services/ChainRegistry/ChainSyncService.swift"
SORA_HISTORY_FACTORY="$ROOT/fearless/CoreLayer/OperationFactory/BlockExplorer/History/Main/SoraSubsquidHistoryOperationFactory.swift"
SORA_PRICE_FETCHER="$ROOT/fearless/ApplicationLayer/Pricing/SoraSubqueryPriceFetcher.swift"
SORA_MAINNET_CHAIN_ID="7e4e32d0feafd4f9c9414b0be86373f9a1efa904809b683453a9af6856d38ad5"
PI_INDEXER_URL="https://pi.soramitsu.io/graphql"
PI_INDEXER_HOST="pi.soramitsu.io"
SORAMETRICS_EXTRINSIC_URL="https://sorametrics.org/sorav2?tab=extrinsics&q={value}"
SORAMETRICS_ACCOUNT_URL="https://sorametrics.org/sorav2?tab=balance&address={value}"
OLD_SORA_PRICE_URL="https://api.subquery.network/sq/sora-xor/sora-prod"
OLD_SORA_EXPLORER_URL="https://sora.subscan.io/{type}/{value}"

fail() {
  echo "[check-sora-pi-indexer] $1" >&2
  exit 1
}

[[ -f "$CHAINS_JSON" ]] || fail "Missing bundled chain registry: $CHAINS_JSON"
[[ -f "$CHAIN_SYNC_SERVICE" ]] || fail "Missing chain sync service: $CHAIN_SYNC_SERVICE"
[[ -f "$SORA_HISTORY_FACTORY" ]] || fail "Missing SORA history factory: $SORA_HISTORY_FACTORY"
[[ -f "$SORA_PRICE_FETCHER" ]] || fail "Missing SORA price fetcher: $SORA_PRICE_FETCHER"

ruby -rjson - "$CHAINS_JSON" "$SORA_MAINNET_CHAIN_ID" "$PI_INDEXER_URL" "$SORAMETRICS_EXTRINSIC_URL" "$SORAMETRICS_ACCOUNT_URL" "$OLD_SORA_PRICE_URL" "$OLD_SORA_EXPLORER_URL" <<'RUBY'
path, chain_id, expected_url, expected_extrinsic_url, expected_account_url, old_price_url, old_explorer_url = ARGV

chains = JSON.parse(File.read(path))
chain = chains.find { |item| item.fetch("chainId", "").casecmp?(chain_id) }

unless chain
  warn "[check-sora-pi-indexer] Missing SORA Mainnet chainId #{chain_id} in #{path}"
  exit 1
end

external_api = chain["externalApi"]
unless external_api.is_a?(Hash)
  warn "[check-sora-pi-indexer] SORA Mainnet externalApi must be an object"
  exit 1
end

%w[history pricing].each do |key|
  api = external_api[key]
  unless api.is_a?(Hash)
    warn "[check-sora-pi-indexer] SORA Mainnet externalApi.#{key} must be an object"
    exit 1
  end

  unless api["type"] == "sora"
    warn "[check-sora-pi-indexer] SORA Mainnet externalApi.#{key}.type is #{api["type"].inspect}, expected \"sora\""
    exit 1
  end

  unless api["url"] == expected_url
    warn "[check-sora-pi-indexer] SORA Mainnet externalApi.#{key}.url is #{api["url"].inspect}, expected #{expected_url.inspect}"
    exit 1
  end
end

explorers = external_api["explorers"]
unless explorers.is_a?(Array)
  warn "[check-sora-pi-indexer] SORA Mainnet externalApi.explorers must be an array"
  exit 1
end

expected_explorers = {
  expected_extrinsic_url => %w[extrinsic],
  expected_account_url => %w[account address]
}

expected_explorers.each do |expected_explorer_url, expected_types|
  explorer = explorers.find { |item| item.is_a?(Hash) && item["url"] == expected_explorer_url }

  unless explorer
    warn "[check-sora-pi-indexer] Missing SORA Mainnet Sorametrics explorer #{expected_explorer_url}"
    exit 1
  end

  unless explorer["type"] == "subscan"
    warn "[check-sora-pi-indexer] Sorametrics explorer type is #{explorer["type"].inspect}, expected \"subscan\" for SSFModels compatibility"
    exit 1
  end

  unless explorer["types"] == expected_types
    warn "[check-sora-pi-indexer] Sorametrics explorer #{expected_explorer_url} types are #{explorer["types"].inspect}, expected #{expected_types.inspect}"
    exit 1
  end
end

if File.read(path).include?(old_price_url)
  warn "[check-sora-pi-indexer] Stale SORA pricing indexer remains in bundled chain registry: #{old_price_url}"
  exit 1
end

if File.read(path).include?(old_explorer_url)
  warn "[check-sora-pi-indexer] Stale SORA Subscan explorer remains in bundled chain registry: #{old_explorer_url}"
  exit 1
end

puts "[check-sora-pi-indexer] OK: SORA Mainnet history/pricing use #{expected_url} and explorers use Sorametrics"
RUBY

grep -Fq "static let soraPiIndexerUrl = \"$PI_INDEXER_URL\"" "$CHAIN_SYNC_SERVICE" \
  || fail "ChainSyncService.soraPiIndexerUrl must be $PI_INDEXER_URL"

grep -Fq 'externalApi["history"] = piApi' "$CHAIN_SYNC_SERVICE" \
  || fail "Remote SORA Mainnet chain sync must force externalApi.history to the PI indexer"

grep -Fq 'externalApi["pricing"] = piApi' "$CHAIN_SYNC_SERVICE" \
  || fail "Remote SORA Mainnet chain sync must force externalApi.pricing to the PI indexer"

grep -Fq "static let soraMetricsExtrinsicUrl = \"$SORAMETRICS_EXTRINSIC_URL\"" "$CHAIN_SYNC_SERVICE" \
  || fail "ChainSyncService.soraMetricsExtrinsicUrl must be $SORAMETRICS_EXTRINSIC_URL"

grep -Fq "static let soraMetricsAccountUrl = \"$SORAMETRICS_ACCOUNT_URL\"" "$CHAIN_SYNC_SERVICE" \
  || fail "ChainSyncService.soraMetricsAccountUrl must be $SORAMETRICS_ACCOUNT_URL"

grep -Fq 'externalApi["explorers"] =' "$CHAIN_SYNC_SERVICE" \
  || fail "Remote SORA Mainnet chain sync must force externalApi.explorers to Sorametrics"

grep -Fq "url.host?.lowercased() == \"$PI_INDEXER_HOST\"" "$SORA_HISTORY_FACTORY" \
  || fail "SORA history factory must keep its PI indexer query branch"

grep -Fq "url.host?.lowercased() == \"$PI_INDEXER_HOST\"" "$SORA_PRICE_FETCHER" \
  || fail "SORA price fetcher must keep its PI indexer query branch"

echo "[check-sora-pi-indexer] OK: remote sync and PI query adapters are wired"
