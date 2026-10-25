#!/usr/bin/env bash
set -euo pipefail

# Drives the app's real Bitcoin and Solana send code against local private chains:
# `bitcoind -regtest` behind scripts/local-chains/esplora_regtest_shim.py, and
# `solana-test-validator` (with an SPL token from scripts/local-chains/solana_spl_fixture.py),
# directly and behind scripts/local-chains/solana_rpc_proxy.py. These chains hold no value and
# the tests refuse any endpoint that is not on 127.0.0.1, so nothing here can reach mainnet or
# testnet.
#
# Usage:
#   scripts/test-local-chain-sends.sh <work-dir> <xcodebuild arguments...>
#
# The xcodebuild arguments select an already built `fearless.tests` target, for example:
#   scripts/test-local-chain-sends.sh /tmp/fearless-chains \
#     -workspace fearless.xcworkspace -scheme fearless.tests \
#     -destination 'platform=iOS Simulator,id=<udid>' -derivedDataPath build/DerivedData \
#     test-without-building
# The script appends `-only-testing` for the local-chain suites and passes the chain
# endpoints as TEST_RUNNER_FEARLESS_E2E_* variables. Without those variables the
# suites skip, so the regular test run never needs local chains.
#
# Overrides: FEARLESS_BITCOIND, FEARLESS_BITCOIN_CLI, FEARLESS_SOLANA_TEST_VALIDATOR,
# FEARLESS_LOCAL_CHAIN_SUITES (space separated -only-testing identifiers),
# FEARLESS_LOCAL_CHAINS (the chains to start: "bitcoin solana" by default; "solana" runs the
# Solana suites without starting bitcoind).

if [[ $# -lt 2 ]]; then
  sed -n '3,26p' "$0" >&2
  exit 64
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$1"
shift

BITCOIND="${FEARLESS_BITCOIND:-$(command -v bitcoind || echo /opt/homebrew/bin/bitcoind)}"
BITCOIN_CLI="${FEARLESS_BITCOIN_CLI:-$(command -v bitcoin-cli || echo /opt/homebrew/bin/bitcoin-cli)}"
SOLANA_TEST_VALIDATOR="${FEARLESS_SOLANA_TEST_VALIDATOR:-$(command -v solana-test-validator || echo /opt/homebrew/bin/solana-test-validator)}"
CHAINS=" ${FEARLESS_LOCAL_CHAINS:-bitcoin solana} "
START_BITCOIN=0
START_SOLANA=0
[[ "$CHAINS" == *" bitcoin "* ]] && START_BITCOIN=1
[[ "$CHAINS" == *" solana "* ]] && START_SOLANA=1
if [[ "$START_BITCOIN$START_SOLANA" == "00" ]]; then
  echo "[local-chains] FEARLESS_LOCAL_CHAINS names no known chain (bitcoin, solana)" >&2
  exit 64
fi
DEFAULT_SUITES=""
[[ "$START_BITCOIN$START_SOLANA" == "11" ]] && DEFAULT_SUITES="fearlessTests/SendLocalChainE2ETests"
[[ "$START_BITCOIN" == 1 ]] && DEFAULT_SUITES="$DEFAULT_SUITES fearlessTests/BitcoinLocalChainE2ETests"
[[ "$START_SOLANA" == 1 ]] && DEFAULT_SUITES="$DEFAULT_SUITES fearlessTests/SolanaLocalChainE2ETests"
SUITES="${FEARLESS_LOCAL_CHAIN_SUITES:-$DEFAULT_SUITES}"
# The SPL fixture's token holder: the Solana address (m/44'/501'/0'/0') of the BIP39 test phrase
# "abandon ... about", which SolanaLocalChainE2ETests signs with. Public test vector, no value.
SPL_HOLDER="HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk"

mkdir -p "$WORK_DIR"
WORK_DIR="$(cd "$WORK_DIR" && pwd)"
rm -rf "$WORK_DIR/bitcoind" "$WORK_DIR/solana"
mkdir -p "$WORK_DIR/bitcoind" "$WORK_DIR/solana"

free_ports() {
  python3 -I - "$1" <<'PY'
import socket, sys
sockets = []
for _ in range(int(sys.argv[1])):
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    sockets.append(s)
print(" ".join(str(s.getsockname()[1]) for s in sockets))
for s in sockets:
    s.close()
PY
}

free_port_range() {
  python3 -I - "$1" <<'PY'
import random, socket, sys
size = int(sys.argv[1])
for _ in range(200):
    start = random.randrange(20000, 60000 - size)
    sockets = []
    try:
        for port in range(start, start + size):
            s = socket.socket()
            s.bind(("127.0.0.1", port))
            sockets.append(s)
    except OSError:
        continue
    finally:
        for s in sockets:
            s.close()
    print(start)
    sys.exit(0)
sys.exit("no free port range")
PY
}

read -r BTC_RPC_PORT BTC_P2P_PORT SHIM_PORT SOL_RPC_PORT SOL_FAUCET_PORT SOL_GOSSIP_PORT SOL_PROXY_PORT <<<"$(free_ports 7)"
SOL_DYNAMIC_START="$(free_port_range 30)"
BTC_RPC_USER="fearless"
BTC_RPC_PASSWORD="$(python3 -I -c 'import secrets; print(secrets.token_hex(16))')"

PIDS=()
cleanup() {
  local pid
  for pid in "${PIDS[@]:-}"; do
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
  done
  for pid in "${PIDS[@]:-}"; do
    [[ -n "$pid" ]] && wait "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT

btc_cli() {
  "$BITCOIN_CLI" -regtest -datadir="$WORK_DIR/bitcoind" -rpcport="$BTC_RPC_PORT" \
    -rpcuser="$BTC_RPC_USER" -rpcpassword="$BTC_RPC_PASSWORD" "$@"
}

if [[ "$START_BITCOIN" == 1 ]]; then
  echo "[local-chains] starting bitcoind -regtest (rpc 127.0.0.1:$BTC_RPC_PORT)"
  "$BITCOIND" -regtest -datadir="$WORK_DIR/bitcoind" -rpcport="$BTC_RPC_PORT" -port="$BTC_P2P_PORT" \
    -rpcbind=127.0.0.1 -rpcallowip=127.0.0.1 -rpcuser="$BTC_RPC_USER" -rpcpassword="$BTC_RPC_PASSWORD" \
    -listen=0 -dnsseed=0 -fixedseeds=0 -txindex=1 -fallbackfee=0.0002 -printtoconsole=0 \
    2>"$WORK_DIR/bitcoind.stderr" &
  PIDS+=("$!")

  for _ in $(seq 1 120); do
    btc_cli getblockchaininfo >/dev/null 2>&1 && break
    sleep 0.5
  done
  btc_cli getblockchaininfo >/dev/null
  btc_cli createwallet miner >/dev/null
  MINER_ADDRESS="$(btc_cli -rpcwallet=miner getnewaddress)"
  btc_cli generatetoaddress 101 "$MINER_ADDRESS" >/dev/null

  echo "[local-chains] starting the Esplora shim (http://127.0.0.1:$SHIM_PORT)"
  python3 -I "$ROOT_DIR/scripts/local-chains/esplora_regtest_shim.py" \
    --rpc-url "http://127.0.0.1:$BTC_RPC_PORT" --rpc-user "$BTC_RPC_USER" --rpc-password "$BTC_RPC_PASSWORD" \
    --port "$SHIM_PORT" --miner-wallet miner 2>"$WORK_DIR/esplora-shim.stderr" &
  PIDS+=("$!")
fi

if [[ "$START_SOLANA" == 1 ]]; then
  echo "[local-chains] writing the SPL token fixture"
  SPL_FIXTURE="$(python3 -I "$ROOT_DIR/scripts/local-chains/solana_spl_fixture.py" "$WORK_DIR/solana/spl" --owner "$SPL_HOLDER")"
  SPL_MINT="$(sed -n 's/^MINT=//p' <<<"$SPL_FIXTURE")"
  SPL_SOURCE="$(sed -n 's/^TOKEN_ACCOUNT_0=//p' <<<"$SPL_FIXTURE")"
  SPL_ACCOUNTS=()
  for file in "$WORK_DIR"/solana/spl/*.json; do
    SPL_ACCOUNTS+=(--account "$(basename "$file" .json)" "$file")
  done

  echo "[local-chains] starting solana-test-validator (rpc 127.0.0.1:$SOL_RPC_PORT)"
  "$SOLANA_TEST_VALIDATOR" --ledger "$WORK_DIR/solana/ledger" --reset --quiet --bind-address 127.0.0.1 \
    --rpc-port "$SOL_RPC_PORT" --faucet-port "$SOL_FAUCET_PORT" --gossip-port "$SOL_GOSSIP_PORT" \
    --dynamic-port-range "$SOL_DYNAMIC_START-$((SOL_DYNAMIC_START + 29))" "${SPL_ACCOUNTS[@]}" \
    >"$WORK_DIR/solana-test-validator.stdout" 2>"$WORK_DIR/solana-test-validator.stderr" &
  PIDS+=("$!")

  echo "[local-chains] starting the Solana RPC proxy (http://127.0.0.1:$SOL_PROXY_PORT)"
  python3 -I "$ROOT_DIR/scripts/local-chains/solana_rpc_proxy.py" \
    --validator-url "http://127.0.0.1:$SOL_RPC_PORT" --port "$SOL_PROXY_PORT" 2>"$WORK_DIR/solana-rpc-proxy.stderr" &
  PIDS+=("$!")
fi

wait_http() {
  local url="$1" body="$2"
  for _ in $(seq 1 180); do
    if curl -sf -H 'content-type: application/json' ${body:+-d "$body"} "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done
  echo "[local-chains] $url did not become ready" >&2
  return 1
}

RUNNER_ENV=()
if [[ "$START_BITCOIN" == 1 ]]; then
  wait_http "http://127.0.0.1:$SHIM_PORT/fee-estimates" ""
  RUNNER_ENV+=("TEST_RUNNER_FEARLESS_E2E_ESPLORA_URL=http://127.0.0.1:$SHIM_PORT")
fi
if [[ "$START_SOLANA" == 1 ]]; then
  wait_http "http://127.0.0.1:$SOL_RPC_PORT" '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
  wait_http "http://127.0.0.1:$SOL_PROXY_PORT/svc/a-primary" '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
  wait_http "http://127.0.0.1:$SOL_RPC_PORT" '{"jsonrpc":"2.0","id":1,"method":"getAccountInfo","params":["'"$SPL_SOURCE"'"]}'

  # Capture the owned validator identity once before the test process. The private fixture
  # explicitly binds to these bytes; production never infers old payment identity this way.
  curl -sf -H 'content-type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"getGenesisHash","params":[]}' \
    "http://127.0.0.1:$SOL_RPC_PORT" > "$WORK_DIR/solana/genesis-response.json"
  SOL_GENESIS_HASH="$(python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); h=d["result"]; assert d["id"]==1 and isinstance(h,str) and h; print(h)' "$WORK_DIR/solana/genesis-response.json")"
  RUNNER_ENV+=(
    "TEST_RUNNER_FEARLESS_E2E_SOLANA_GENESIS_HASH=$SOL_GENESIS_HASH"
    "TEST_RUNNER_FEARLESS_E2E_SOLANA_RPC_URL=http://127.0.0.1:$SOL_RPC_PORT"
    "TEST_RUNNER_FEARLESS_E2E_SOLANA_PROXY_URL=http://127.0.0.1:$SOL_PROXY_PORT"
    "TEST_RUNNER_FEARLESS_E2E_SOLANA_SPL_MINT=$SPL_MINT"
    "TEST_RUNNER_FEARLESS_E2E_SOLANA_SPL_SOURCE=$SPL_SOURCE"
  )
fi

ONLY_TESTING=()
for suite in $SUITES; do
  ONLY_TESTING+=("-only-testing:$suite")
done

echo "[local-chains] running ${SUITES}"
set +e
env "${RUNNER_ENV[@]}" xcodebuild "${ONLY_TESTING[@]}" "$@"
STATUS=$?
set -e

if [[ "$START_BITCOIN" == 1 ]]; then
  echo "[local-chains] bitcoind height $(btc_cli getblockcount), mempool $(btc_cli getmempoolinfo | tr -d '\n ' )"
fi
exit "$STATUS"
