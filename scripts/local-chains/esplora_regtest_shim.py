#!/usr/bin/env python3
"""A tiny Esplora-compatible HTTP server over a local `bitcoind -regtest`.

It exists only for the local-chain send tests (scripts/test-local-chain-sends.sh)
and never talks to mainnet or testnet. It serves the endpoints the wallet's
Bitcoin code calls (address stats, UTXOs, fee estimates, broadcast, transaction
status, outspends) plus a few `/regtest/...` controls the tests use to fund a
wallet, mine blocks and inspect the mempool.

It behaves like Blockstream's electrs where the wallet's safety depends on it:
`/tx/:txid` answers 404 for a transaction it has never seen, while
`/tx/:txid/status` answers `{"confirmed": false}` for the same unknown
transaction, exactly as for a mempool transaction.

Several Esplora services can be simulated over the one node: a path that starts
with `/svc/<name>/` is served as service `<name>` (the tests map mempool.space
and blockstream.info onto two of them). `/regtest/faults` makes a service fail
in the ways a public indexer does (rate limits, server errors, a broadcast the
node accepted whose reply is lost), and `/regtest/requests` reports what each
service was asked, so failover and backoff can be asserted.

The wallet's Bitcoin code knows mainnet and testnet. Regtest shares testnet's
BIP84 coin type and differs only in the bech32 prefix, so the shim accepts
testnet `tb1...` addresses and maps them onto regtest `bcrt1...` scripts, and
reports regtest addresses back as `tb1...`. Transactions carry scripts, not
prefixes, so the bytes the wallet signs are valid on regtest unchanged.

Usage: esplora_regtest_shim.py --rpc-url URL --rpc-user USER --rpc-password PW
                               --port PORT [--miner-wallet NAME]
"""

import argparse
import base64
import json
import sys
import threading
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SATS_PER_BTC = 100_000_000
# Regtest has no fee market; these mirror the shape of Esplora's /fee-estimates.
STATIC_FEE_ESTIMATES = {"1": 3.0, "2": 2.0, "3": 2.0, "6": 1.5, "144": 1.0, "504": 1.0, "1008": 1.0}

BECH32_CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
BECH32_CONST = 1
BECH32M_CONST = 0x2BC830A3


def _polymod(values):
    generator = [0x3B6A57B2, 0x26508E6D, 0x1EA119FA, 0x3D4233DD, 0x2A1462B3]
    checksum = 1
    for value in values:
        top = checksum >> 25
        checksum = (checksum & 0x1FFFFFF) << 5 ^ value
        for index in range(5):
            checksum ^= generator[index] if ((top >> index) & 1) else 0
    return checksum


def _hrp_expand(hrp):
    return [ord(char) >> 5 for char in hrp] + [0] + [ord(char) & 31 for char in hrp]


def bech32_decode(address):
    """Returns (hrp, data, const) or None for an invalid bech32/bech32m string."""
    if address.lower() != address and address.upper() != address:
        return None
    address = address.lower()
    separator = address.rfind("1")
    if separator < 1 or separator + 7 > len(address) or len(address) > 90:
        return None
    hrp = address[:separator]
    try:
        data = [BECH32_CHARSET.index(char) for char in address[separator + 1:]]
    except ValueError:
        return None
    const = _polymod(_hrp_expand(hrp) + data)
    if const not in (BECH32_CONST, BECH32M_CONST):
        return None
    return hrp, data[:-6], const


def bech32_encode(hrp, data, const):
    values = _hrp_expand(hrp) + data
    polymod = _polymod(values + [0, 0, 0, 0, 0, 0]) ^ const
    checksum = [(polymod >> 5 * (5 - index)) & 31 for index in range(6)]
    return hrp + "1" + "".join(BECH32_CHARSET[value] for value in data + checksum)


def recode(address, hrp):
    decoded = bech32_decode(address)
    if decoded is None:
        return address
    _, data, const = decoded
    return bech32_encode(hrp, data, const)


def to_regtest_address(address):
    return recode(address, "bcrt") if address.lower().startswith("tb1") else address


def to_testnet_address(address):
    return recode(address, "tb") if address and address.lower().startswith("bcrt1") else address


def to_sats(btc):
    return int(round(btc * SATS_PER_BTC))


class BitcoindRpc:
    def __init__(self, url, user, password):
        self.url = url.rstrip("/")
        token = base64.b64encode(f"{user}:{password}".encode()).decode()
        self.authorization = f"Basic {token}"
        self.lock = threading.Lock()
        self.next_id = 1

    def call(self, method, params=None, wallet=None):
        with self.lock:
            request_id = self.next_id
            self.next_id += 1
        url = f"{self.url}/wallet/{wallet}" if wallet else self.url
        body = json.dumps({"jsonrpc": "1.0", "id": request_id, "method": method, "params": params or []})
        request = urllib.request.Request(
            url,
            data=body.encode(),
            headers={"Authorization": self.authorization, "Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                payload = json.loads(response.read())
        except urllib.error.HTTPError as error:
            payload = json.loads(error.read() or b"{}")
        if payload.get("error"):
            raise RpcError(payload["error"].get("code"), payload["error"].get("message"))
        return payload.get("result")


class RpcError(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code
        self.message = message


def empty_stats():
    return {"funded_txo_count": 0, "funded_txo_sum": 0, "spent_txo_count": 0, "spent_txo_sum": 0, "tx_count": 0}


class ChainIndex:
    """Outputs, spends and statuses for the whole regtest chain plus the mempool."""

    def __init__(self, rpc, block_cache):
        self.outputs = {}
        self.spends = {}
        self.statuses = {}
        blocks = []
        block_hash = rpc.call("getbestblockhash")
        while block_hash:
            block = block_cache.get(block_hash)
            if block is None:
                block = rpc.call("getblock", [block_hash, 2])
                block_cache[block_hash] = block
            blocks.append(block)
            block_hash = block.get("previousblockhash")
        for block in reversed(blocks):
            status = {
                "confirmed": True,
                "block_height": block["height"],
                "block_hash": block["hash"],
                "block_time": block["time"],
            }
            for transaction in block["tx"]:
                self._add(transaction, status)
        for txid in rpc.call("getrawmempool"):
            try:
                self._add(rpc.call("getrawtransaction", [txid, True]), {"confirmed": False})
            except RpcError:
                pass  # evicted between the two calls

    def _add(self, transaction, status):
        txid = transaction["txid"]
        self.statuses[txid] = status
        for output in transaction["vout"]:
            self.outputs[f"{txid}:{output['n']}"] = {
                "address": output.get("scriptPubKey", {}).get("address"),
                "status": status,
                "txid": txid,
                "value": to_sats(output["value"]),
                "vout": output["n"],
            }
        for vin, spent in enumerate(transaction["vin"]):
            if "coinbase" in spent:
                continue
            self.spends[f"{spent['txid']}:{spent['vout']}"] = {"status": status, "txid": txid, "vin": vin}

    def address_stats(self, address):
        chain, mempool = empty_stats(), empty_stats()
        chain_txs, mempool_txs = set(), set()
        for outpoint, output in self.outputs.items():
            if output["address"] != address:
                continue
            funded = chain if output["status"]["confirmed"] else mempool
            funded["funded_txo_count"] += 1
            funded["funded_txo_sum"] += output["value"]
            (chain_txs if output["status"]["confirmed"] else mempool_txs).add(output["txid"])
            spend = self.spends.get(outpoint)
            if spend:
                spent = chain if spend["status"]["confirmed"] else mempool
                spent["spent_txo_count"] += 1
                spent["spent_txo_sum"] += output["value"]
                (chain_txs if spend["status"]["confirmed"] else mempool_txs).add(spend["txid"])
        chain["tx_count"] = len(chain_txs)
        mempool["tx_count"] = len(mempool_txs)
        return {"chain_stats": chain, "mempool_stats": mempool}

    def address_utxos(self, address):
        return [
            {"txid": output["txid"], "vout": output["vout"], "value": output["value"], "status": output["status"]}
            for outpoint, output in self.outputs.items()
            if output["address"] == address and outpoint not in self.spends
        ]


class DropConnection(Exception):
    """Closes the connection without any response, like a reply lost on the way back."""


class Shim:
    def __init__(self, rpc, miner_wallet):
        self.rpc = rpc
        self.miner_wallet = miner_wallet
        self.block_cache = {}
        self.requests = {}
        self.faults = []
        self.lock = threading.Lock()
        self.faults_lock = threading.Lock()

    def index(self):
        with self.lock:
            return ChainIndex(self.rpc, self.block_cache)

    def transaction(self, txid, index):
        raw = self.rpc.call("getrawtransaction", [txid, 2])
        vin = []
        for spent in raw["vin"]:
            entry = {"is_coinbase": "coinbase" in spent, "sequence": spent.get("sequence")}
            if "coinbase" not in spent:
                prevout = spent.get("prevout", {})
                entry.update({
                    "txid": spent["txid"],
                    "vout": spent["vout"],
                    "witness": spent.get("txinwitness", []),
                    "prevout": {
                        "scriptpubkey": prevout.get("scriptPubKey", {}).get("hex"),
                        "scriptpubkey_address": to_testnet_address(prevout.get("scriptPubKey", {}).get("address")),
                        "value": to_sats(prevout.get("value", 0)),
                    },
                })
            vin.append(entry)
        vout = [
            {
                "scriptpubkey": output["scriptPubKey"]["hex"],
                "scriptpubkey_address": to_testnet_address(output["scriptPubKey"].get("address")),
                "value": to_sats(output["value"]),
            }
            for output in raw["vout"]
        ]
        fee = to_sats(raw["fee"]) if "fee" in raw else None
        if fee is None:
            # Bitcoin Core reports the fee of a mempool transaction only in its mempool entry;
            # Esplora reports it for mempool transactions too.
            try:
                fee = to_sats(self.rpc.call("getmempoolentry", [txid])["fees"]["base"])
            except RpcError:
                fee = None
        return {
            "txid": raw["txid"],
            "version": raw["version"],
            "locktime": raw["locktime"],
            "size": raw["size"],
            "weight": raw["weight"],
            "fee": fee,
            "vin": vin,
            "vout": vout,
            "status": index.statuses.get(txid, {"confirmed": False}),
        }

    def mine(self, blocks):
        address = self.rpc.call("getnewaddress", [], wallet=self.miner_wallet)
        return self.rpc.call("generatetoaddress", [blocks, address])

    def take_fault(self, service, route):
        """Returns the next fault armed for this service and route, if any, and uses it up."""
        with self.faults_lock:
            for fault in self.faults:
                if fault["service"] in (service, "*") and fault["route"] in (route, "any") and fault["count"] > 0:
                    fault["count"] -= 1
                    return fault
        return None

    def handle(self, method, path, body):
        parts = [part for part in path.split("?")[0].split("/") if part]
        service = "default"
        if parts[:1] == ["svc"] and len(parts) >= 2:
            service = parts[1]
            parts = parts[2:]

        if parts[:1] != ["regtest"]:
            with self.faults_lock:
                self.requests.setdefault(service, []).append(f"{method} /{'/'.join(parts)}")
            route = "broadcast" if method == "POST" and parts == ["tx"] else "lookup" if parts[:1] == ["tx"] else "read"
            fault = self.take_fault(service, route)
            if fault is not None:
                outcome = self.apply_fault(fault, method, parts, body)
                if outcome is not None:
                    return outcome

        if method == "POST" and parts == ["tx"]:
            try:
                return 200, "text/plain", self.rpc.call("sendrawtransaction", [body.strip()])
            except RpcError as error:
                detail = json.dumps({"code": error.code, "message": error.message})
                return 400, "text/plain", f"sendrawtransaction RPC error: {detail}"

        if method == "POST" and parts[:1] == ["regtest"]:
            request = json.loads(body or "{}")
            if parts[1:] == ["faults"]:
                with self.faults_lock:
                    self.faults.append({
                        "service": request.get("service", "*"),
                        "route": request.get("route", "any"),
                        "mode": request["mode"],
                        "count": int(request.get("count", 1)),
                        "retry_after": request.get("retry_after"),
                    })
                return 200, "application/json", "{}"
            if parts[1:] == ["reset"]:
                with self.faults_lock:
                    self.faults = []
                    self.requests = {}
                return 200, "application/json", "{}"
            if parts[1:] == ["address"]:
                return 200, "application/json", json.dumps({"address": self.new_address(request["type"])})
            if parts[1:] == ["fund"]:
                address = to_regtest_address(request["address"])
                txid = self.rpc.call(
                    "sendtoaddress",
                    [address, request["sats"] / SATS_PER_BTC],
                    wallet=self.miner_wallet,
                )
                if request.get("confirm", True):
                    self.mine(1)
                return 200, "application/json", json.dumps({"txid": txid})
            if parts[1:] == ["mine"]:
                return 200, "application/json", json.dumps(self.mine(int(request.get("blocks", 1))))
            return 404, "text/plain", "Not found"

        if method != "GET":
            return 405, "text/plain", "Method not allowed"
        if parts == ["fee-estimates"]:
            return 200, "application/json", json.dumps(STATIC_FEE_ESTIMATES)
        if parts == ["regtest", "mempool"]:
            return 200, "application/json", json.dumps(self.rpc.call("getrawmempool"))
        if parts == ["regtest", "requests"]:
            with self.faults_lock:
                return 200, "application/json", json.dumps(self.requests)
        if parts == ["blocks", "tip", "height"]:
            return 200, "text/plain", str(self.rpc.call("getblockcount"))

        index = self.index()
        if parts[:1] == ["address"] and len(parts) >= 2:
            requested = parts[1]
            address = to_regtest_address(requested)
            if len(parts) == 2:
                return 200, "application/json", json.dumps({"address": requested, **index.address_stats(address)})
            if parts[2] == "utxo":
                return 200, "application/json", json.dumps(index.address_utxos(address))
            if parts[2] == "txs":
                return 200, "application/json", "[]"
        if parts[:1] == ["tx"] and len(parts) >= 2:
            txid = parts[1]
            if len(parts) == 2:
                try:
                    return 200, "application/json", json.dumps(self.transaction(txid, index))
                except RpcError:
                    return 404, "text/plain", "Transaction not found"
            if parts[2] == "status":
                # electrs answers an unknown transaction like a mempool one, so this route
                # cannot tell "never seen" from "waiting for a block".
                return 200, "application/json", json.dumps(index.statuses.get(txid, {"confirmed": False}))
            if parts[2] == "hex":
                try:
                    return 200, "text/plain", self.rpc.call("getrawtransaction", [txid, False])
                except RpcError:
                    return 404, "text/plain", "Transaction not found"
            if parts[2] == "outspend" and len(parts) == 4:
                spend = index.spends.get(f"{txid}:{int(parts[3])}")
                payload = {"spent": True, **spend} if spend else {"spent": False}
                return 200, "application/json", json.dumps(payload)
        return 404, "text/plain", "Not found"

    def apply_fault(self, fault, method, parts, body):
        mode = fault["mode"]
        if mode == "429":
            headers = {"Retry-After": str(fault["retry_after"])} if fault.get("retry_after") is not None else {}
            return 429, "text/plain", "Too Many Requests", headers
        if mode in ("500", "502", "503"):
            return int(mode), "text/plain", "Service unavailable"
        if mode == "drop":
            raise DropConnection()
        if mode in ("accept_then_502", "accept_then_drop") and method == "POST" and parts == ["tx"]:
            try:
                self.rpc.call("sendrawtransaction", [body.strip()])
            except RpcError:
                pass
            if mode == "accept_then_drop":
                raise DropConnection()
            return 502, "text/plain", "Bad Gateway"
        return None

    def new_address(self, kind):
        """A miner-wallet address of the given type, spelled for the wallet's testnet code."""
        if kind == "p2wsh":
            pubkey = self.rpc.call(
                "getaddressinfo",
                [self.rpc.call("getnewaddress", ["", "bech32"], wallet=self.miner_wallet)],
                wallet=self.miner_wallet,
            )["pubkey"]
            address = self.rpc.call("createmultisig", [1, [pubkey], "bech32"])["address"]
        else:
            address = self.rpc.call("getnewaddress", ["", kind], wallet=self.miner_wallet)
        return to_testnet_address(address)


def make_handler(shim):
    class Handler(BaseHTTPRequestHandler):
        def _respond(self, method):
            length = int(self.headers.get("Content-Length") or 0)
            body = self.rfile.read(length).decode() if length else ""
            headers = {}
            try:
                result = shim.handle(method, self.path, body)
                status, content_type, payload = result[:3]
                if len(result) > 3:
                    headers = result[3]
            except DropConnection:
                self.close_connection = True
                return
            except Exception as error:  # noqa: BLE001 - report any shim failure to the test
                status, content_type, payload = 500, "text/plain", str(error)
            data = payload.encode()
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(data)))
            for name, value in headers.items():
                self.send_header(name, value)
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):  # noqa: N802 - BaseHTTPRequestHandler naming
            self._respond("GET")

        def do_POST(self):  # noqa: N802 - BaseHTTPRequestHandler naming
            self._respond("POST")

        def log_message(self, format, *args):  # noqa: A002 - signature from the base class
            sys.stderr.write("[esplora-shim] " + (format % args) + "\n")

    return Handler


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--rpc-url", required=True)
    parser.add_argument("--rpc-user", required=True)
    parser.add_argument("--rpc-password", required=True)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--miner-wallet", default="miner")
    arguments = parser.parse_args()

    shim = Shim(BitcoindRpc(arguments.rpc_url, arguments.rpc_user, arguments.rpc_password), arguments.miner_wallet)
    server = ThreadingHTTPServer(("127.0.0.1", arguments.port), make_handler(shim))
    sys.stderr.write(f"[esplora-shim] listening on http://127.0.0.1:{arguments.port}\n")
    server.serve_forever()


if __name__ == "__main__":
    main()
