#!/usr/bin/env python3
"""Open a Fearless iOS emergency recovery file.

The iOS app (4.2.1 and later) writes its "Emergency recovery material" export as
`fearless-emergency-material-encrypted-v1`:

    {
      "format": "fearless-emergency-material-encrypted-v1",
      "encoding": ["scrypt", "xsalsa20-poly1305"],
      "encoded": base64(salt[32] | N u32le | p u32le | r u32le | nonce[24] | box),
      "records": <count>,
      "unreadable": <count>
    }

`box` is NaCl secretbox (XSalsa20-Poly1305, 16-byte tag first) of the
`fearless-emergency-material-v1` JSON, keyed by scrypt(password as UTF-8, salt,
N, r, p, 32 bytes). That is the layout of a Polkadot JSON keystore's `encoded`
field, so polkadot.js `jsonDecryptData` opens it too.

This script needs only the Python standard library. It prints the decrypted
v1 JSON, whose records hold each Keychain item's original bytes in Base64. Run
it offline, on a computer you trust, and delete the output when you are done:
anyone holding it controls the wallets.

Usage:
    python3 -I decrypt-emergency-material.py fearless-emergency-recovery.json
    python3 -I decrypt-emergency-material.py FILE --out material.json
    python3 -I decrypt-emergency-material.py --self-test
"""

import argparse
import base64
import getpass
import hashlib
import hmac
import json
import os
import struct
import sys

FORMAT = "fearless-emergency-material-encrypted-v1"
ENCODING = ["scrypt", "xsalsa20-poly1305"]
PLAINTEXT_FORMAT = "fearless-emergency-material-v1"
SALT_LENGTH = 32
SCRYPT_HEADER_LENGTH = 44
NONCE_LENGTH = 24
TAG_LENGTH = 16
KEY_LENGTH = 32
MAX_FILE_BYTES = 64 * 1024 * 1024

# Bounds that keep a damaged or hostile file from exhausting memory.
MAX_SCRYPT_N = 1 << 20
MAX_SCRYPT_R = 16
MAX_SCRYPT_P = 16


class RecoveryFileError(Exception):
    pass


# --- Salsa20 / HSalsa20 -----------------------------------------------------

_SIGMA = (0x61707865, 0x3320646E, 0x79622D32, 0x6B206574)


def _rotl(value, shift):
    return ((value << shift) & 0xFFFFFFFF) | (value >> (32 - shift))


def _salsa20_rounds(words, double_rounds=10):
    x = list(words)
    for _ in range(double_rounds):
        # Column round.
        x[4] ^= _rotl((x[0] + x[12]) & 0xFFFFFFFF, 7)
        x[8] ^= _rotl((x[4] + x[0]) & 0xFFFFFFFF, 9)
        x[12] ^= _rotl((x[8] + x[4]) & 0xFFFFFFFF, 13)
        x[0] ^= _rotl((x[12] + x[8]) & 0xFFFFFFFF, 18)
        x[9] ^= _rotl((x[5] + x[1]) & 0xFFFFFFFF, 7)
        x[13] ^= _rotl((x[9] + x[5]) & 0xFFFFFFFF, 9)
        x[1] ^= _rotl((x[13] + x[9]) & 0xFFFFFFFF, 13)
        x[5] ^= _rotl((x[1] + x[13]) & 0xFFFFFFFF, 18)
        x[14] ^= _rotl((x[10] + x[6]) & 0xFFFFFFFF, 7)
        x[2] ^= _rotl((x[14] + x[10]) & 0xFFFFFFFF, 9)
        x[6] ^= _rotl((x[2] + x[14]) & 0xFFFFFFFF, 13)
        x[10] ^= _rotl((x[6] + x[2]) & 0xFFFFFFFF, 18)
        x[3] ^= _rotl((x[15] + x[11]) & 0xFFFFFFFF, 7)
        x[7] ^= _rotl((x[3] + x[15]) & 0xFFFFFFFF, 9)
        x[11] ^= _rotl((x[7] + x[3]) & 0xFFFFFFFF, 13)
        x[15] ^= _rotl((x[11] + x[7]) & 0xFFFFFFFF, 18)
        # Row round.
        x[1] ^= _rotl((x[0] + x[3]) & 0xFFFFFFFF, 7)
        x[2] ^= _rotl((x[1] + x[0]) & 0xFFFFFFFF, 9)
        x[3] ^= _rotl((x[2] + x[1]) & 0xFFFFFFFF, 13)
        x[0] ^= _rotl((x[3] + x[2]) & 0xFFFFFFFF, 18)
        x[6] ^= _rotl((x[5] + x[4]) & 0xFFFFFFFF, 7)
        x[7] ^= _rotl((x[6] + x[5]) & 0xFFFFFFFF, 9)
        x[4] ^= _rotl((x[7] + x[6]) & 0xFFFFFFFF, 13)
        x[5] ^= _rotl((x[4] + x[7]) & 0xFFFFFFFF, 18)
        x[11] ^= _rotl((x[10] + x[9]) & 0xFFFFFFFF, 7)
        x[8] ^= _rotl((x[11] + x[10]) & 0xFFFFFFFF, 9)
        x[9] ^= _rotl((x[8] + x[11]) & 0xFFFFFFFF, 13)
        x[10] ^= _rotl((x[9] + x[8]) & 0xFFFFFFFF, 18)
        x[12] ^= _rotl((x[15] + x[14]) & 0xFFFFFFFF, 7)
        x[13] ^= _rotl((x[12] + x[15]) & 0xFFFFFFFF, 9)
        x[14] ^= _rotl((x[13] + x[12]) & 0xFFFFFFFF, 13)
        x[15] ^= _rotl((x[14] + x[13]) & 0xFFFFFFFF, 18)
    return x


def _initial_state(key, middle):
    k = struct.unpack("<8I", key)
    m = struct.unpack("<4I", middle)
    return [
        _SIGMA[0], k[0], k[1], k[2],
        k[3], _SIGMA[1], m[0], m[1],
        m[2], m[3], _SIGMA[2], k[4],
        k[5], k[6], k[7], _SIGMA[3],
    ]


def _hsalsa20(key, nonce16):
    x = _salsa20_rounds(_initial_state(key, nonce16))
    return struct.pack("<8I", x[0], x[5], x[10], x[15], x[6], x[7], x[8], x[9])


def _salsa20_keystream(key, nonce8, length):
    blocks = []
    counter = 0
    while sum(len(block) for block in blocks) < length:
        state = _initial_state(key, nonce8 + struct.pack("<Q", counter))
        mixed = _salsa20_rounds(state)
        blocks.append(struct.pack("<16I", *((a + b) & 0xFFFFFFFF for a, b in zip(mixed, state))))
        counter += 1
    return b"".join(blocks)[:length]


# --- Poly1305 -----------------------------------------------------------------

def _poly1305(key, message):
    r = int.from_bytes(key[:16], "little") & 0x0FFFFFFC0FFFFFFC0FFFFFFC0FFFFFFF
    s = int.from_bytes(key[16:32], "little")
    p = (1 << 130) - 5
    accumulator = 0
    for offset in range(0, len(message), 16):
        block = message[offset:offset + 16] + b"\x01"
        accumulator = (accumulator + int.from_bytes(block, "little")) * r % p
    return ((accumulator + s) & ((1 << 128) - 1)).to_bytes(16, "little")


# --- NaCl secretbox -----------------------------------------------------------

def secretbox_seal(message, nonce, key):
    if len(key) != KEY_LENGTH or len(nonce) != NONCE_LENGTH:
        raise ValueError("secretbox needs a 32-byte key and a 24-byte nonce")
    subkey = _hsalsa20(key, nonce[:16])
    stream = _salsa20_keystream(subkey, nonce[16:], 32 + len(message))
    ciphertext = bytes(a ^ b for a, b in zip(message, stream[32:]))
    return _poly1305(stream[:32], ciphertext) + ciphertext


def secretbox_open(box, nonce, key):
    if len(key) != KEY_LENGTH or len(nonce) != NONCE_LENGTH:
        raise ValueError("secretbox needs a 32-byte key and a 24-byte nonce")
    if len(box) < TAG_LENGTH:
        raise RecoveryFileError("the encrypted data is truncated")
    subkey = _hsalsa20(key, nonce[:16])
    tag, ciphertext = box[:TAG_LENGTH], box[TAG_LENGTH:]
    stream = _salsa20_keystream(subkey, nonce[16:], 32 + len(ciphertext))
    if not hmac.compare_digest(_poly1305(stream[:32], ciphertext), tag):
        raise RecoveryFileError("wrong password, or the file is damaged")
    return bytes(a ^ b for a, b in zip(ciphertext, stream[32:]))


# --- File format ----------------------------------------------------------------

# --- scrypt (RFC 7914) ----------------------------------------------------------
#
# hashlib.scrypt is used when Python was built with an OpenSSL that has it. The
# Python that ships with macOS was not, so a plain implementation follows. It
# takes about a minute for the app's parameters (N=32768, r=8, p=1).

def _blockmix(words, r):
    x = words[-16:]
    even, odd = [], []
    for i in range(2 * r):
        mixed = [a ^ b for a, b in zip(x, words[16 * i:16 * i + 16])]
        rounds = _salsa20_rounds(mixed, double_rounds=4)
        x = [(a + b) & 0xFFFFFFFF for a, b in zip(rounds, mixed)]
        (even if i % 2 == 0 else odd).extend(x)
    return even + odd


def _romix(block, n, r):
    packer = struct.Struct("<%dI" % (32 * r))
    x = list(packer.unpack(block))
    table = []
    for _ in range(n):
        table.append(packer.pack(*x))
        x = _blockmix(x, r)
    for _ in range(n):
        j = x[(2 * r - 1) * 16] & (n - 1)
        x = _blockmix([a ^ b for a, b in zip(x, packer.unpack(table[j]))], r)
    return packer.pack(*x)


def scrypt_reference(password, salt, n, r, p, length):
    blocks = hashlib.pbkdf2_hmac("sha256", password, salt, 1, p * 128 * r)
    mixed = b"".join(
        _romix(blocks[128 * r * i:128 * r * (i + 1)], n, r) for i in range(p)
    )
    return hashlib.pbkdf2_hmac("sha256", password, mixed, 1, length)


def _scrypt_key(password, salt, n, r, p):
    if n < 2 or n & (n - 1) or n > MAX_SCRYPT_N or not 1 <= r <= MAX_SCRYPT_R or not 1 <= p <= MAX_SCRYPT_P:
        raise RecoveryFileError("unsupported scrypt parameters N=%d r=%d p=%d" % (n, r, p))
    if hasattr(hashlib, "scrypt"):
        memory = 128 * r * n + 128 * r * p + 1024 * 1024
        return hashlib.scrypt(password, salt=salt, n=n, r=r, p=p, maxmem=memory, dklen=KEY_LENGTH)
    if n >= 4096:
        print("Deriving the key without OpenSSL scrypt; this takes about a minute...", file=sys.stderr)
    return scrypt_reference(password, salt, n, r, p, KEY_LENGTH)


def decrypt_file(data, password):
    if len(data) > MAX_FILE_BYTES:
        raise RecoveryFileError("the file is too large to be a recovery file")
    try:
        envelope = json.loads(data.decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        raise RecoveryFileError("the file is not JSON")
    if not isinstance(envelope, dict) or envelope.get("format") != FORMAT:
        raise RecoveryFileError("the file is not a %s file" % FORMAT)
    if envelope.get("encoding") != ENCODING:
        raise RecoveryFileError("unsupported encoding %r" % envelope.get("encoding"))
    try:
        encoded = base64.b64decode(envelope.get("encoded", ""), validate=True)
    except (ValueError, TypeError):
        raise RecoveryFileError("the encoded field is not Base64")
    if len(encoded) < SCRYPT_HEADER_LENGTH + NONCE_LENGTH + TAG_LENGTH:
        raise RecoveryFileError("the encrypted data is truncated")

    salt = encoded[:SALT_LENGTH]
    n, p, r = struct.unpack("<3I", encoded[SALT_LENGTH:SCRYPT_HEADER_LENGTH])
    nonce = encoded[SCRYPT_HEADER_LENGTH:SCRYPT_HEADER_LENGTH + NONCE_LENGTH]
    box = encoded[SCRYPT_HEADER_LENGTH + NONCE_LENGTH:]

    key = _scrypt_key(password, salt, n, r, p)
    plaintext = secretbox_open(box, nonce, key)
    material = json.loads(plaintext.decode("utf-8"))
    if not isinstance(material, dict) or material.get("format") != PLAINTEXT_FORMAT:
        raise RecoveryFileError("the decrypted content is not %s" % PLAINTEXT_FORMAT)
    return material


def encrypt_material(material, password, salt=None, nonce=None, n=32768, r=8, p=1):
    """Builds a file the way the app does; used by the self-test and by tests."""
    salt = os.urandom(SALT_LENGTH) if salt is None else salt
    nonce = os.urandom(NONCE_LENGTH) if nonce is None else nonce
    plaintext = json.dumps(material, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    key = _scrypt_key(password, salt, n, r, p)
    encoded = salt + struct.pack("<3I", n, p, r) + nonce + secretbox_seal(plaintext, nonce, key)
    envelope = {
        "encoded": base64.b64encode(encoded).decode("ascii"),
        "encoding": ENCODING,
        "format": FORMAT,
        "records": len(material.get("records", [])),
        "unreadable": len(material.get("unreadableTags", [])),
    }
    return json.dumps(envelope, indent=2, sort_keys=True).encode("utf-8")


# --- Self-test ----------------------------------------------------------------------

# "Cryptography in NaCl" (Bernstein), secretbox example: firstkey, nonce, message, box.
_NACL_KEY = bytes.fromhex("1b27556473e985d462cd51197a9a46c76009549eac6474f206c4ee0844f68389")
_NACL_NONCE = bytes.fromhex("69696ee955b62b73cd62bda875fc73d68219e0036b7a0b37")
_NACL_MESSAGE = bytes.fromhex(
    "be075fc53c81f2d5cf141316ebeb0c7b5228c52a4c62cbd44b66849b64244ffc"
    "e5ecbaaf33bd751a1ac728d45e6c61296cdc3c01233561f41db66cce314adb31"
    "0e3be8250c46f06dceea3a7fa1348057e2f6556ad6b1318a024a838f21af1fde"
    "048977eb48f59ffd4924ca1c60902e52f0a089bc76897040e082f93776384864"
    "5e0705"
)
_NACL_BOX = bytes.fromhex(
    "f3ffc7703f9400e52a7dfb4b3d3305d9"
    "8e993b9f48681273c29650ba32fc76ce48332ea7164d96a4476fb8c531a1186a"
    "c0dfc17c98dce87b4da7f011ec48c97271d2c20f9b928fe2270d6fb863d51738"
    "b48eeee314a7cc8ab932164548e526ae90224368517acfeabd6bb3732bc0e9da"
    "99832b61ca01b6de56244a9e88d5f9b37973f622a43d14a6599b1f654cb45a74"
    "e355a5"
)


# RFC 7914 section 12, first two vectors.
_SCRYPT_VECTORS = [
    (b"", b"", 16, 1, 1,
     "77d6576238657b203b19ca42c18a0497f16b4844e3074ae8dfdffa3fede21442"
     "fcd0069ded0948f8326a753a0fc81f17e8d3e0fb2e0d3628cf35e20c38d18906"),
    (b"password", b"NaCl", 1024, 8, 16,
     "fdbabe1c9d3472007856e7190d01e9fe7c6ad7cbc8237830e77376634b373162"
     "2eaf30d92e22a3886ff109279d9830dac727afb94a83ee6d8360cbdfa2cc0640"),
]


def self_test(full=False):
    vectors = _SCRYPT_VECTORS if full else _SCRYPT_VECTORS[:1]
    for password, salt, n, r, p, expected in vectors:
        derived = scrypt_reference(password, salt, n, r, p, 64)
        assert derived.hex() == expected, "RFC 7914 scrypt vector N=%d" % n
    assert secretbox_seal(_NACL_MESSAGE, _NACL_NONCE, _NACL_KEY) == _NACL_BOX, "NaCl secretbox vector"
    assert secretbox_open(_NACL_BOX, _NACL_NONCE, _NACL_KEY) == _NACL_MESSAGE, "NaCl secretbox open"
    tampered = bytearray(_NACL_BOX)
    tampered[-1] ^= 1
    try:
        secretbox_open(bytes(tampered), _NACL_NONCE, _NACL_KEY)
    except RecoveryFileError:
        pass
    else:
        raise AssertionError("a tampered box must not open")

    material = {
        "format": PLAINTEXT_FORMAT,
        "records": [{"bytesBase64": base64.b64encode(b"\x00\x01\xff").decode(), "tag": "meta-entropy"}],
        "unreadableTags": ["meta-seed"],
    }
    file = encrypt_material(material, b"correct horse", n=1024)
    assert decrypt_file(file, b"correct horse") == material, "round trip"
    try:
        decrypt_file(file, b"wrong horse")
    except RecoveryFileError:
        pass
    else:
        raise AssertionError("a wrong password must not open the file")
    return True


def main(argv=None):
    parser = argparse.ArgumentParser(description="Open a Fearless iOS emergency recovery file.")
    parser.add_argument("file", nargs="?", help="the fearless-emergency-recovery.json file")
    parser.add_argument("--out", help="write the decrypted JSON here (mode 0600) instead of standard output")
    parser.add_argument("--password-stdin", action="store_true", help="read the password from standard input")
    parser.add_argument("--self-test", action="store_true", help="check the built-in cryptography and exit")
    parser.add_argument("--full", action="store_true", help="with --self-test, also run the slow scrypt vector")
    args = parser.parse_args(argv)

    if args.self_test:
        self_test(full=args.full)
        print("self-test passed")
        return 0

    if not args.file:
        parser.error("give the recovery file to open")

    with open(args.file, "rb") as handle:
        data = handle.read(MAX_FILE_BYTES + 1)

    if args.password_stdin:
        password = sys.stdin.readline().rstrip("\r\n")
    else:
        password = getpass.getpass("Password: ")

    try:
        material = decrypt_file(data, password.encode("utf-8"))
    except RecoveryFileError as error:
        print("error: %s" % error, file=sys.stderr)
        return 1

    output = json.dumps(material, indent=2, sort_keys=True) + "\n"
    if args.out:
        descriptor = os.open(args.out, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(output)
    else:
        sys.stdout.write(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
