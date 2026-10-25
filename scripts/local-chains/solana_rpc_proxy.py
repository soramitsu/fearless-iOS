#!/usr/bin/env python3
"""A JSON-RPC proxy in front of a local `solana-test-validator` that can fail like public nodes.

It exists only for the local-chain send tests (scripts/test-local-chain-sends.sh) and forwards
only to the validator URL it is given, which must be on 127.0.0.1.

Several RPC nodes can be simulated over the one validator: a request to `/svc/<name>` is
served as node `<name>` (the tests give the wallet two of them, so its failover is exercised).
`POST /proxy/faults` arms a fault for a node and JSON-RPC method:

  {"service": "a-primary", "method": "sendTransaction", "mode": "accept_then_drop", "count": 1}

Modes:
  403, 429, 500, 502          answer with that HTTP status without forwarding
  rpc_blocked                 answer {"error": {"code": -32602, "message": "Request blocked"}}
                              without forwarding (what solana-rpc.publicnode.com does for
                              getTokenAccountsByOwner)
  drop                        close the connection without forwarding (nothing reached the node)
  accept_then_drop            forward, then close the connection without the reply (a lost reply)
  accept_then_502             forward, then answer 502 (a gateway that lost the reply)

`GET /proxy/requests` reports the methods each node was asked; `POST /proxy/reset` clears
faults and the request log.

Usage: solana_rpc_proxy.py --validator-url http://127.0.0.1:8899 --port PORT
"""

import argparse
import json
import sys
import threading
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse


class DropConnection(Exception):
    """Closes the connection without any response."""


class Proxy:
    def __init__(self, validator_url):
        self.validator_url = validator_url
        self.faults = []
        self.requests = {}
        self.lock = threading.Lock()

    def forward(self, body):
        request = urllib.request.Request(
            self.validator_url,
            data=body.encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.status, response.read().decode()
        except urllib.error.HTTPError as error:
            return error.code, error.read().decode()

    def take_fault(self, service, method):
        with self.lock:
            for fault in self.faults:
                if fault["service"] in (service, "*") and fault["method"] in (method, "*") and fault["count"] > 0:
                    fault["count"] -= 1
                    return fault
        return None

    def handle(self, http_method, path, body):
        parts = [part for part in urlparse(path).path.split("/") if part]

        if parts[:1] == ["proxy"]:
            if http_method == "POST" and parts[1:] == ["faults"]:
                request = json.loads(body or "{}")
                with self.lock:
                    self.faults.append({
                        "service": request.get("service", "*"),
                        "method": request.get("method", "*"),
                        "mode": request["mode"],
                        "count": int(request.get("count", 1)),
                    })
                return 200, "{}"
            if http_method == "POST" and parts[1:] == ["reset"]:
                with self.lock:
                    self.faults = []
                    self.requests = {}
                return 200, "{}"
            if http_method == "GET" and parts[1:] == ["requests"]:
                with self.lock:
                    return 200, json.dumps(self.requests)
            return 404, "{}"

        if http_method != "POST":
            return 405, "{}"

        service = parts[1] if parts[:1] == ["svc"] and len(parts) >= 2 else "default"
        try:
            rpc_method = json.loads(body).get("method", "?")
        except ValueError:
            rpc_method = "?"
        with self.lock:
            self.requests.setdefault(service, []).append(rpc_method)

        fault = self.take_fault(service, rpc_method)
        mode = fault["mode"] if fault else None
        if mode in ("403", "429", "500", "502"):
            return int(mode), json.dumps({"error": f"simulated {mode}"})
        if mode == "rpc_blocked":
            request_id = json.loads(body).get("id")
            return 200, json.dumps({
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {"code": -32602, "message": "Request blocked"},
            })
        if mode == "drop":
            raise DropConnection()

        status, payload = self.forward(body)
        if mode == "accept_then_drop":
            raise DropConnection()
        if mode == "accept_then_502":
            return 502, json.dumps({"error": "simulated lost reply"})
        return status, payload


def make_handler(proxy):
    class Handler(BaseHTTPRequestHandler):
        def _respond(self, method):
            length = int(self.headers.get("Content-Length") or 0)
            body = self.rfile.read(length).decode() if length else ""
            try:
                status, payload = proxy.handle(method, self.path, body)
            except DropConnection:
                self.close_connection = True
                return
            except Exception as error:  # noqa: BLE001 - report any proxy failure to the test
                status, payload = 500, json.dumps({"error": str(error)})
            data = payload.encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):  # noqa: N802 - BaseHTTPRequestHandler naming
            self._respond("GET")

        def do_POST(self):  # noqa: N802 - BaseHTTPRequestHandler naming
            self._respond("POST")

        def log_message(self, format, *args):  # noqa: A002 - signature from the base class
            sys.stderr.write("[solana-rpc-proxy] " + (format % args) + "\n")

    return Handler


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--validator-url", required=True)
    parser.add_argument("--port", type=int, required=True)
    arguments = parser.parse_args()

    if urlparse(arguments.validator_url).hostname not in ("127.0.0.1", "localhost"):
        sys.exit("the validator must be local")

    server = ThreadingHTTPServer(("127.0.0.1", arguments.port), make_handler(Proxy(arguments.validator_url)))
    sys.stderr.write(f"[solana-rpc-proxy] listening on http://127.0.0.1:{arguments.port}\n")
    server.serve_forever()


if __name__ == "__main__":
    main()
