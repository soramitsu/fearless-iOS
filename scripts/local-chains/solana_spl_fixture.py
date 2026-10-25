#!/usr/bin/env python3
"""Write genesis accounts for an SPL token on solana-test-validator.

The validator loads each file with `--account <address> <file>`, so the local chain starts with
an initialized SPL mint and token accounts holding that mint. No keypair, CLI or network is
needed: the accounts are written in the SPL Token program's own layout (Mint: 82 bytes,
Account: 165 bytes) and owned by the Token program.

Usage:
  solana_spl_fixture.py <out-dir> --owner <base58 wallet> [--owner <base58 wallet> ...]
                        [--decimals 6] [--amount 1000000000]

Prints `MINT=<address>` and one `TOKEN_ACCOUNT_<n>=<address>` line per owner, and writes
`<address>.json` for the mint and every token account. Addresses are derived from the owner
list, so reruns produce the same files.
"""

import argparse
import base64
import hashlib
import json
import struct
import sys
from pathlib import Path

TOKEN_PROGRAM = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
# Generous balances: well above the rent-exempt minimum for these sizes on any cluster.
MINT_LAMPORTS = 10_000_000
TOKEN_ACCOUNT_LAMPORTS = 10_000_000


def b58decode(value):
    number = 0
    for char in value:
        number = number * 58 + ALPHABET.index(char)
    raw = number.to_bytes((number.bit_length() + 7) // 8, "big") if number else b""
    pad = len(value) - len(value.lstrip("1"))
    data = b"\x00" * pad + raw
    if len(data) != 32:
        raise ValueError(f"not a 32-byte public key: {value}")
    return data


def b58encode(data):
    number = int.from_bytes(data, "big")
    out = ""
    while number:
        number, rem = divmod(number, 58)
        out = ALPHABET[rem] + out
    pad = len(data) - len(data.lstrip(b"\x00"))
    return "1" * pad + out


def derived_address(*labels):
    return b58encode(hashlib.sha256(b"fearless-local-spl|" + b"|".join(labels)).digest())


def none_option(size):
    return struct.pack("<I", 0) + b"\x00" * size


def mint_data(supply, decimals):
    return none_option(32) + struct.pack("<QBB", supply, decimals, 1) + none_option(32)


def token_account_data(mint, owner, amount):
    data = (
        b58decode(mint)
        + b58decode(owner)
        + struct.pack("<Q", amount)
        + none_option(32)  # delegate
        + bytes([1])  # AccountState::Initialized
        + none_option(8)  # is_native
        + struct.pack("<Q", 0)  # delegated_amount
        + none_option(32)  # close_authority
    )
    assert len(data) == 165
    return data


def account_json(address, lamports, data):
    return {
        "pubkey": address,
        "account": {
            "lamports": lamports,
            "data": [base64.b64encode(data).decode(), "base64"],
            "owner": TOKEN_PROGRAM,
            "executable": False,
            "rentEpoch": 0,
            "space": len(data),
        },
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("out_dir", type=Path)
    parser.add_argument("--owner", action="append", required=True)
    parser.add_argument("--decimals", type=int, default=6)
    parser.add_argument("--amount", type=int, default=1_000_000_000)
    args = parser.parse_args()

    for owner in args.owner:
        b58decode(owner)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    seed = "|".join(args.owner).encode()
    mint = derived_address(b"mint", seed)
    data = mint_data(args.amount * len(args.owner), args.decimals)
    assert len(data) == 82
    (args.out_dir / f"{mint}.json").write_text(json.dumps(account_json(mint, MINT_LAMPORTS, data)))
    print(f"MINT={mint}")

    for index, owner in enumerate(args.owner):
        address = derived_address(b"token-account", seed, str(index).encode())
        data = token_account_data(mint, owner, args.amount)
        (args.out_dir / f"{address}.json").write_text(json.dumps(account_json(address, TOKEN_ACCOUNT_LAMPORTS, data)))
        print(f"TOKEN_ACCOUNT_{index}={address}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
