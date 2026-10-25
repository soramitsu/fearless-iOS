#!/usr/bin/env python3
"""Check the vendored Ed25519/BLAKE2 C sources against public vectors and the binaries they replace.

One operation list runs through a C harness linked against the previous XCFramework
archives (read from git history) and against the vendored sources at -O0 and -Os, and
through an Objective-C harness over the IrohaCrypto wrappers. It holds the public vectors
in Tests/Ed25519Blake2Native/vectors.json, random cases whose results come from an
independent Python model (RFC 8032 arithmetic, RFC 7748 ladder, hashlib), and malformed
inputs that only the old binaries can answer. Every build must print exactly what the old
archives print. Runs use an iOS simulator; device arm64 is linked, and simulator x86_64
is linked and also run when the simulator can execute it.

--host-asan runs the source-built harnesses on macOS with AddressSanitizer and
checks every independently specified result without using the old iOS archives.
"""

import argparse
import hashlib
import json
import random
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
TESTS = ROOT / "Tests" / "Ed25519Blake2Native"
ED = ROOT / "Sources" / "libed25519"
B2 = ROOT / "Sources" / "blake2lib"
IROHA = ROOT / "Sources" / "IrohaCrypto"
LIBRARY_INCLUDES = {
    ED: ["iroha-ed25519-build", "iroha-ed25519/include", "ed25519-sha2/include", "ed25519-sha2/src", "include"],
    B2: ["blake2_mjosref/include", "include"],
}
HARNESS_INCLUDES = [ED / "ed25519-sha2" / "include", ED / "ed25519-sha2" / "src", IROHA / "include"]
WRAPPER_SOURCES = ["ed25519", "Iroha", "blake2", "Common", "BIP39"]
SIMULATOR = {"arm64": "arm64-apple-ios14.0-simulator", "x86_64": "x86_64-apple-ios14.0-simulator"}
DEVICE = "arm64-apple-ios14.0"
SEED = 20261023


# Independent model -------------------------------------------------------------------

P = 2 ** 255 - 19
L = 2 ** 252 + 27742317777372353535851937790883648493
D = -121665 * pow(121666, P - 2, P) % P
IDENTITY = (0, 1, 1, 0)


def inverse(x):
    return pow(x, P - 2, P)


def point_add(p, q):
    a = (p[1] - p[0]) * (q[1] - q[0]) % P
    b = (p[1] + p[0]) * (q[1] + q[0]) % P
    c = 2 * p[3] * q[3] * D % P
    d = 2 * p[2] * q[2] % P
    e, f, g, h = b - a, d - c, d + c, b + a
    return (e * f % P, g * h % P, f * g % P, e * h % P)


def scalar_mult(scalar, point):
    result = IDENTITY
    while scalar:
        if scalar & 1:
            result = point_add(result, point)
        point = point_add(point, point)
        scalar >>= 1
    return result


def recover_x(y, sign):
    if y >= P:
        return None
    x2 = (y * y - 1) * inverse(D * y * y + 1) % P
    if x2 == 0:
        return None if sign else 0
    x = pow(x2, (P + 3) // 8, P)
    if (x * x - x2) % P:
        x = x * pow(2, (P - 1) // 4, P) % P
    if (x * x - x2) % P:
        return None
    return P - x if (x & 1) != sign else x


BASE_Y = 4 * inverse(5) % P
BASE = (recover_x(BASE_Y, 0), BASE_Y, 1, recover_x(BASE_Y, 0) * BASE_Y % P)


def compress(point):
    z = inverse(point[2])
    x, y = point[0] * z % P, point[1] * z % P
    return (y | ((x & 1) << 255)).to_bytes(32, "little")


def decompress(data):
    y = int.from_bytes(data, "little")
    sign, y = y >> 255, y & ((1 << 255) - 1)
    x = recover_x(y, sign)
    return None if x is None else (x, y, 1, x * y % P)


def clamp(digest):
    scalar = bytearray(digest[:32])
    scalar[0] &= 248
    scalar[31] &= 63
    scalar[31] |= 64
    return bytes(scalar)


def public_from_scalar(scalar):
    return compress(scalar_mult(int.from_bytes(scalar, "little"), BASE))


def sign(hash_function, scalar, prefix, public, message):
    """RFC 8032 signing with an explicit scalar, nonce prefix and (unchecked) public key."""
    r = int.from_bytes(hash_function(prefix + message), "little") % L
    encoded_r = public_from_scalar(r.to_bytes(32, "little"))
    k = int.from_bytes(hash_function(encoded_r + public + message), "little") % L
    s = (r + k * int.from_bytes(scalar, "little")) % L
    return encoded_r + s.to_bytes(32, "little")


def sha512(data):
    return hashlib.sha512(data).digest()


def scalar_nonce_prefix(scalar):
    """EDPrivateKey's nonce prefix for a key created from a raw scalar instead of a seed."""
    return sha512(b"IrohaCrypto EDPrivateKey nonce prefix" + scalar)[:32]


def sha3_512(data):
    return hashlib.sha3_512(data).digest()


def x25519_ladder(k, u):
    x1, x2, z2, x3, z3, swap = u, 1, 0, u, 1, 0
    for t in reversed(range(255)):
        bit = (k >> t) & 1
        swap ^= bit
        if swap:
            x2, x3, z2, z3 = x3, x2, z3, z2
        swap = bit
        a, b = (x2 + z2) % P, (x2 - z2) % P
        aa, bb = a * a % P, b * b % P
        e = (aa - bb) % P
        c, d = (x3 + z3) % P, (x3 - z3) % P
        da, cb = d * a % P, c * b % P
        x3, z3 = (da + cb) ** 2 % P, x1 * (da - cb) ** 2 % P
        x2, z2 = aa * bb % P, e * (aa + 121665 * e) % P
    if swap:
        x2, z2 = x3, z3
    return (x2 * inverse(z2) % P).to_bytes(32, "little")


def key_exchange(public, private):
    """orlp ed25519_key_exchange: X25519 of the clamped scalar with the Edwards y mapped to u."""
    y = int.from_bytes(public, "little") & ((1 << 255) - 1)
    u = (1 + y) * inverse((1 - y) % P) % P
    return x25519_ladder(int.from_bytes(clamp(private), "little"), u)


def add_scalar(public, private, scalar):
    """orlp ed25519_add_scalar: a' = a + n mod L with a rehashed nonce prefix; A' = A + nB."""
    n = bytearray(scalar)
    n[31] &= 127
    n = int.from_bytes(n, "little")
    if private is not None:
        a = (int.from_bytes(private[:32], "little") + n) % L
        prefix = sha512(private[32:] + scalar)[:32]
        private = a.to_bytes(32, "little") + prefix
    if public is not None:
        if private is not None:
            public = public_from_scalar(private[:32])
        else:
            public = compress(point_add(scalar_mult(n, BASE), decompress(public)))
    return public, private


def blake2(algorithm, outlen, key, message):
    function = hashlib.blake2b if algorithm == "b" else hashlib.blake2s
    return function(message, digest_size=outlen, key=key).digest()


# Operation list ----------------------------------------------------------------------

def hx(data):
    return data.hex() if data else "-"


class Plan:
    def __init__(self):
        self.lines = []
        self.expected = []
        self.groups = {}

    def add(self, line, expected=None, group=None):
        if group:
            self.groups.setdefault(group, []).append(len(self.lines))
        self.lines.append(line)
        self.expected.append(expected)

    def write(self, path):
        path.write_text("".join(line + "\n" for line in self.lines))


def chunks(rng):
    return ",".join(str(rng.choice([0, 1, 7, 63, 64, 65, 127, 128, 129, rng.randrange(1, 300)]))
                    for _ in range(rng.randrange(1, 6)))


def message(rng):
    return rng.randbytes(rng.choice([0, 1, 2, 3, 31, 32, 33, 63, 64, 65, 111, 112, 127, 128, 129,
                                     rng.randrange(256), rng.randrange(4096)]))


def corrupt(rng, data):
    data = bytearray(data)
    data[rng.randrange(len(data))] ^= 1 << rng.randrange(8)
    return bytes(data)


def edge_signatures(signature):
    s = int.from_bytes(signature[32:], "little")
    high = [s + L, s + 2 * L, s + (1 << 252), (1 << 253) - 1, 1 << 253, L, L - 1, 0]
    return ([signature[:32] + value.to_bytes(32, "little") for value in high if value < 1 << 256]
            + [bytes(64), b"\xff" * 64, bytes(32) + signature[32:], signature[32:] + signature[:32]])


# Encodings of small-order points, non-canonical y and points off the curve.
EDGE_KEYS = [bytes.fromhex(value) for value in (
    "0100000000000000000000000000000000000000000000000000000000000000",
    "0000000000000000000000000000000000000000000000000000000000000000",
    "0000000000000000000000000000000000000000000000000000000000000080",
    "ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f",
    "eeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f",
    "edffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f",
    "c7176a703d4dd84fba3c0b760d10670f2a2053fa2c39ccc64ec7fd7792ac037a",
    "26e8958fc2b227b045c3f489f2ef98f0d5dfac05d3c63339b13802886d53fc05",
    "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    "0200000000000000000000000000000000000000000000000000000000000000",
)]


def native_plan(vectors, rng, scale):
    plan = Plan()
    for algorithm, width in (("b", 64), ("s", 32)):
        for keyed in (False, True):
            key = bytes(range(width)) if keyed else b""
            group = f"blake2{algorithm}-{'keyed' if keyed else 'unkeyed'}"
            for length in range(256):
                data = bytes(range(length))
                plan.add(f"b2{algorithm} {width} {hx(key)} {hx(data)}",
                         "0 " + blake2(algorithm, width, key, data).hex(), group)
    plan.add("b2b 64 - 616263", "0 " + vectors["blake2_abc"]["blake2b_512"])
    plan.add("b2s 32 - 616263", "0 " + vectors["blake2_abc"]["blake2s_256"])
    for algorithm, width in (("b", 64), ("s", 32)):
        for _ in range(600 * scale):
            outlen = rng.randrange(1, width + 1)
            key = rng.randbytes(rng.choice([0, 0, 1, width, rng.randrange(width + 1)]))
            data = message(rng)
            plan.add(f"b2{algorithm} {outlen} {hx(key)} {hx(data)}",
                     "0 " + blake2(algorithm, outlen, key, data).hex())
        for _ in range(200 * scale):
            outlen, key, data = rng.randrange(1, width + 1), rng.randbytes(rng.randrange(width + 1)), message(rng)
            plan.add(f"b2{algorithm}_inc {outlen} {hx(key)} {hx(data)} {chunks(rng)}",
                     "0 " + blake2(algorithm, outlen, key, data).hex())
        for outlen, keylen in ((0, 0), (width + 1, 0), (1, width + 1), (width, width), (1, 0), (255, 255)):
            valid = 1 <= outlen <= width and keylen <= width
            plan.add(f"b2{algorithm}_init {outlen} {keylen}", "0" if valid else "-1")
        plan.add(f"b2{algorithm} 0 - 616263", "-1 -")
        plan.add(f"b2{algorithm} {width + 1} - 616263", "-1 -")

    for case in vectors["sha3"]:
        data = bytes.fromhex(case["message"])
        plan.add(f"sha3_256 {hx(data)}", "1 " + case["sha256"])
        plan.add(f"sha3_512 {hx(data)}", "1 " + case["sha512"])
    for case in vectors["sha2_512"]:
        plan.add(f"sha2_512 {case['message'] or '-'}", "0 " + case["sha512"])
    for _ in range(200 * scale):
        data = message(rng)
        plan.add(f"sha3_256 {hx(data)}", "1 " + hashlib.sha3_256(data).hexdigest())
        plan.add(f"sha3_512 {hx(data)}", "1 " + hashlib.sha3_512(data).hexdigest())
        plan.add(f"sha2_512 {hx(data)}", "0 " + hashlib.sha512(data).hexdigest())
    for _ in range(100 * scale):
        data = message(rng)
        plan.add(f"sha3_256_inc {hx(data)} {chunks(rng)}", hashlib.sha3_256(data).hexdigest())
        plan.add(f"sha3_512_inc {hx(data)} {chunks(rng)}", hashlib.sha3_512(data).hexdigest())
        plan.add(f"sha2_512_inc {hx(data)} {chunks(rng)}", hashlib.sha512(data).hexdigest())

    keypairs = []
    for case in vectors["ed25519"]:
        seed, public, data = bytes.fromhex(case["seed"]), bytes.fromhex(case["public"]), bytes.fromhex(case["message"])
        digest = sha512(seed)
        private = clamp(digest) + digest[32:]
        plan.add(f"ed_keypair {seed.hex()}", f"{public.hex()} {private.hex()}")
        plan.add(f"ed_sign {hx(data)} {public.hex()} {private.hex()}", case["signature"])
        plan.add(f"ed_verify {case['signature']} {hx(data)} {public.hex()}", "1")
        keypairs.append((public, private, data, bytes.fromhex(case["signature"])))
    for _ in range(120 * scale):
        seed, data = rng.randbytes(32), message(rng)
        digest = sha512(seed)
        private = clamp(digest) + digest[32:]
        public = public_from_scalar(private[:32])
        signature = sign(sha512, private[:32], private[32:], public, data)
        plan.add(f"ed_keypair {seed.hex()}", f"{public.hex()} {private.hex()}")
        plan.add(f"ed_sign {hx(data)} {public.hex()} {private.hex()}", signature.hex())
        plan.add(f"ed_verify {signature.hex()} {hx(data)} {public.hex()}", "1")
        keypairs.append((public, private, data, signature))
    for _ in range(40 * scale):
        private, public, data = rng.randbytes(64), rng.randbytes(32), message(rng)
        plan.add(f"ed_sign {hx(data)} {public.hex()} {private.hex()}",
                 sign(sha512, private[:32], private[32:], public, data).hex())
    for _ in range(60 * scale):
        scalar = bytearray(rng.randbytes(32))
        scalar[31] &= 127
        plan.add(f"ed_derive {bytes(scalar).hex()}", public_from_scalar(bytes(scalar)).hex())
    for _ in range(30 * scale):
        scalar = bytearray(rng.randbytes(32))
        scalar[31] |= 128
        plan.add(f"ed_derive {bytes(scalar).hex()}")
    for public, private, _, _ in keypairs[:40 * scale]:
        other = keypairs[rng.randrange(len(keypairs))][0]
        plan.add(f"ed_kex {other.hex()} {private.hex()}", key_exchange(other, private).hex())
    for key in EDGE_KEYS:
        plan.add(f"ed_kex {key.hex()} {keypairs[0][1].hex()}")
    for public, private, _, _ in keypairs[:40 * scale]:
        scalar = rng.randbytes(32)
        for mode in ("both", "public", "private"):
            pub = public if mode != "private" else None
            priv = private if mode != "public" else None
            new_public, new_private = add_scalar(pub, priv, scalar)
            plan.add(f"ed_add_scalar {hx(pub)} {hx(priv)} {scalar.hex()}",
                     f"{hx(new_public)} {hx(new_private)}")
    for public, private, data, signature in keypairs:
        plan.add(f"ed_verify {corrupt(rng, signature).hex()} {hx(data)} {public.hex()}")
        plan.add(f"ed_verify {signature.hex()} {hx(corrupt(rng, data) if data else b'x')} {public.hex()}")
        plan.add(f"ed_verify {signature.hex()} {hx(data)} {corrupt(rng, public).hex()}")
    for public, _, data, signature in keypairs[:10]:
        for variant in edge_signatures(signature):
            plan.add(f"ed_verify {variant.hex()} {hx(data)} {public.hex()}")
        for key in EDGE_KEYS:
            plan.add(f"ed_verify {signature.hex()} {hx(data)} {key.hex()}")

    iroha = []
    for case in vectors["ed25519_sha3"]:
        seed, public, data = bytes.fromhex(case["seed"]), bytes.fromhex(case["public"]), bytes.fromhex(case["message"])
        plan.add(f"ir_derive {seed.hex()}", public.hex())
        plan.add(f"ir_sign {hx(data)} {public.hex()} {seed.hex()}", case["signature"])
        plan.add(f"ir_verify {case['signature']} {hx(data)} {public.hex()}", "1")
        iroha.append((public, seed, data, bytes.fromhex(case["signature"])))
    for _ in range(100 * scale):
        seed, data = rng.randbytes(32), message(rng)
        digest = sha3_512(seed)
        public = public_from_scalar(clamp(digest))
        signature = sign(sha3_512, clamp(digest), digest[32:], public, data)
        plan.add(f"ir_derive {seed.hex()}", public.hex())
        plan.add(f"ir_sign {hx(data)} {public.hex()} {seed.hex()}", signature.hex())
        plan.add(f"ir_verify {signature.hex()} {hx(data)} {public.hex()}", "1")
        iroha.append((public, seed, data, signature))
    for public, _, data, signature in iroha:
        plan.add(f"ir_verify {corrupt(rng, signature).hex()} {hx(data)} {public.hex()}")
        plan.add(f"ir_verify {signature.hex()} {hx(corrupt(rng, data) if data else b'x')} {public.hex()}")
        plan.add(f"ir_verify {signature.hex()} {hx(data)} {corrupt(rng, public).hex()}")
    for public, _, data, signature in iroha[:10]:
        for variant in edge_signatures(signature):
            plan.add(f"ir_verify {variant.hex()} {hx(data)} {public.hex()}")
        for key in EDGE_KEYS:
            plan.add(f"ir_verify {signature.hex()} {hx(data)} {key.hex()}")

    for _ in range(3 * scale):
        plan.add("ir_keypair", "1 1")
        plan.add("ed_seed", "0")
        plan.add("randombytes 32", "1")
    return plan, keypairs, iroha


def wrapper_plan(vectors, rng, keypairs, iroha, scale):
    plan = Plan()
    for public, private, data, signature in keypairs:
        plan.add(f"ed_from_private {private[:32].hex()}", public.hex())
        plan.add(f"ed_verify {signature.hex()} {hx(data)} {public.hex()}", "1")
        plan.add(f"ed_verify {corrupt(rng, signature).hex()} {hx(data)} {public.hex()}")
    for case in vectors["ed25519"]:
        digest = sha512(bytes.fromhex(case["seed"]))
        plan.add(f"ed_seed {case['seed']}", f"{case['public']} {clamp(digest).hex()}")
        plan.add(f"ed_seed_sign {case['seed']} {hx(bytes.fromhex(case['message']))}", case["signature"])
    for _ in range(40 * scale):
        seed, data = rng.randbytes(32), message(rng)
        digest = sha512(seed)
        public = public_from_scalar(clamp(digest))
        plan.add(f"ed_seed {seed.hex()}", f"{public.hex()} {clamp(digest).hex()}")
        plan.add(f"ed_seed_sign {seed.hex()} {hx(data)}",
                 sign(sha512, clamp(digest), digest[32:], public, data).hex())
    for _ in range(20 * scale):
        scalar = clamp(sha512(rng.randbytes(32)))
        plan.add(f"ed_sign_verifies {scalar.hex()} {hx(message(rng))}", "1")
    for _ in range(20 * scale):
        scalar, data = clamp(sha512(rng.randbytes(32))), message(rng)
        expected = sign(sha512, scalar, scalar_nonce_prefix(scalar), public_from_scalar(scalar), data).hex()
        plan.add(f"ed_scalar_sign {scalar.hex()} {hx(data)}", expected)
        plan.add(f"ed_foreign_sign {scalar.hex()} {hx(data)}", expected)
    for length in (0, 16, 31, 33, 64):
        plan.add(f"ed_foreign_sign {hx(bytes(range(length)))} 616263", "nil")
    for public, seed, data, signature in iroha:
        plan.add(f"ir_from_private {seed.hex()}", public.hex())
        plan.add(f"ir_sign {seed.hex()} {hx(data)}", signature.hex())
        plan.add(f"ir_verify {signature.hex()} {hx(data)} {public.hex()}", "1")
    for _ in range(100 * scale):
        data = message(rng)
        for length in (rng.randrange(1, 33), 32):
            plan.add(f"blake2s {length} {hx(data)}", blake2("s", length, b"", data).hex())
        for length in (rng.randrange(1, 65), 32, 64):
            plan.add(f"blake2b {length} {hx(data)}", blake2("b", length, b"", data).hex())
        plan.add(f"sha3_256 {hx(data)}", hashlib.sha3_256(data).hexdigest())
        plan.add(f"sha3_512 {hx(data)}", hashlib.sha3_512(data).hexdigest())
    plan.add("blake2b 65 616263", "nil")
    plan.add("blake2s 33 616263", "nil")
    for case in vectors["substrate_ed25519"]:
        plan.add(f"substrate_ed {case['phrase'].encode().hex()} {case['junction'].encode().hex()}",
                 f"{case['mini_secret']} {case['seed']} {case['public']}")
        digest, data = sha512(bytes.fromhex(case["seed"])), message(rng)
        plan.add(f"ed_seed_sign {case['seed']} {hx(data)}",
                 sign(sha512, clamp(digest), digest[32:], bytes.fromhex(case["public"]), data).hex())
    return plan


# Builds ------------------------------------------------------------------------------

def run(*args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, text=True, **kwargs)


def clang(sdk, target, *args):
    sanitizer = ["-fsanitize=address", "-fno-omit-frame-pointer"] if sdk == "macosx" else []
    run("xcrun", "--sdk", sdk, "clang", "-target", target, *sanitizer, *args)


def library_objects(sdk, target, optimization, stage):
    objects = []
    for root, includes in LIBRARY_INCLUDES.items():
        for index, source in enumerate(sorted(root.rglob("*.c"))):
            output = stage / f"{root.name}-{index}-{source.stem}.o"
            clang(sdk, target, optimization, "-c", *[f"-I{root / path}" for path in includes],
                  str(source), "-o", str(output))
            objects.append(str(output))
    return objects


def wrapper_sources():
    return [str(source) for folder in WRAPPER_SOURCES
            for source in sorted((IROHA / "Classes" / folder).glob("*.m"))]


def link(sdk, target, output, header_flags, libraries, objc=False, optimization="-O0"):
    includes = [f"-I{path}" for path in HARNESS_INCLUDES]
    if objc:
        includes += [f"-I{IROHA / 'Classes' / 'Iroha'}", f"-I{IROHA}"]
        sources = [str(TESTS / "wrappers.m"), *wrapper_sources()]
        frameworks = ["-fobjc-arc", "-framework", "Foundation", "-framework", "Security"]
    else:
        sources = [str(TESTS / "native_ops.c")]
        frameworks = []
    clang(sdk, target, optimization, *frameworks, *header_flags, *includes, *sources, *libraries,
          "-o", str(output))
    return output


def legacy_slices(vectors, stage):
    """Write the replaced frameworks from git history and check their archive hashes."""
    legacy = vectors["legacy_binaries"]
    revision = legacy["revision"]
    if subprocess.run(["git", "-C", str(ROOT), "cat-file", "-e", f"{revision}^{{commit}}"],
                      capture_output=True).returncode:
        run("git", "-C", str(ROOT), "fetch", "--quiet", "--depth", "1", "origin", revision)
    paths = run("git", "-C", str(ROOT), "ls-tree", "-r", "--name-only", revision,
                "Binaries/libed25519.xcframework", "Binaries/blake2lib.xcframework").stdout.split()
    for path in paths:
        data = subprocess.run(["git", "-C", str(ROOT), "show", f"{revision}:{path}"],
                              check=True, capture_output=True).stdout
        if path in legacy["archives"] and hashlib.sha256(data).hexdigest() != legacy["archives"][path]:
            raise SystemExit(f"{path} at {revision} does not match its recorded SHA-256")
        destination = stage / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
    return stage / "Binaries"


def legacy_link(sdk, target, slice_name, binaries, output, objc=False):
    frameworks = [binaries / f"{name}.xcframework" / slice_name for name in ("libed25519", "blake2lib")]
    header_flags = [f"-F{path}" for path in frameworks]
    libraries = [str(frameworks[0] / "libed25519.framework" / "libed25519"),
                 str(frameworks[1] / "blake2lib.framework" / "blake2lib")]
    return link(sdk, target, output, header_flags, libraries, objc=objc)


def source_link(sdk, target, optimization, objects, output, objc=False):
    header_flags = [f"-I{ED / 'include'}", f"-I{B2 / 'include'}"]
    return link(sdk, target, output, header_flags, objects, objc=objc, optimization=optimization)


# Simulator ---------------------------------------------------------------------------

def simulator_device(requested, arch):
    """Return (udid, runtime name) for the requested device, or the newest iOS runtime that runs arch."""
    runtimes = json.loads(run("xcrun", "simctl", "list", "runtimes", "available", "--json").stdout)["runtimes"]
    devices = json.loads(run("xcrun", "simctl", "list", "devices", "available", "--json").stdout)["devices"]
    names = {runtime["identifier"]: runtime["name"] for runtime in runtimes}
    if requested:
        for identifier, entries in devices.items():
            if any(device["udid"] == requested for device in entries):
                return requested, names.get(identifier, identifier)
        raise SystemExit(f"Simulator {requested} is not available")
    ios = [runtime for runtime in runtimes if runtime.get("platform", runtime["name"].split()[0]) == "iOS"
           and arch in runtime.get("supportedArchitectures", [arch])]
    for runtime in sorted(ios, key=lambda item: [int(part) for part in item["version"].split(".")], reverse=True):
        for device in devices.get(runtime["identifier"], []):
            if device.get("isAvailable"):
                return device["udid"], runtime["name"]
    return None, None


def execute(device, binary, operations):
    result = subprocess.run(["xcrun", "simctl", "spawn", "-s", device, str(binary), str(operations)],
                            capture_output=True, text=True)
    if result.returncode:
        return None, result.stderr.strip()
    return result.stdout.splitlines(), None


def check(name, plan, outputs, reference):
    problems = []
    for label, lines in outputs.items():
        if len(lines) != len(plan.lines):
            problems.append(f"{name}/{label}: {len(lines)} results for {len(plan.lines)} operations")
            continue
        for index, (line, actual) in enumerate(zip(plan.lines, lines)):
            expected = plan.expected[index]
            if expected is not None and actual != expected:
                problems.append(f"{name}/{label}: `{line[:120]}` gave `{actual[:140]}`, "
                                f"expected `{expected[:140]}`")
                break
            if actual != outputs[reference][index]:
                problems.append(f"{name}/{label}: `{line[:120]}` gave `{actual[:140]}`, "
                                f"{reference} gave `{outputs[reference][index][:140]}`")
                break
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", help="arm64 simulator UDID (default: a device of the newest iOS runtime)")
    parser.add_argument("--x86-device", help="x86_64 simulator UDID (default: a device of the newest iOS "
                                             "runtime that still runs x86_64)")
    parser.add_argument("--seed", type=int, default=SEED, help="seed for the random cases")
    parser.add_argument("--scale", type=int, default=1, help="multiply the number of random cases")
    parser.add_argument("--host-asan", action="store_true",
                        help="run source-built native and wrapper cases on macOS with AddressSanitizer")
    parser.add_argument("--xcode-products", type=Path,
                        help="Build/Products/<config>-iphonesimulator directory holding Xcode-built "
                             "libed25519.o and blake2lib.o to run as well")
    args = parser.parse_args()
    vectors = json.loads((TESTS / "vectors.json").read_text())
    rng = random.Random(args.seed)
    native, keypairs, iroha = native_plan(vectors, rng, args.scale)
    wrappers = wrapper_plan(vectors, rng, keypairs, iroha, args.scale)
    if args.host_asan:
        target = run("uname", "-m").stdout.strip() + "-apple-macosx13.0"
        with tempfile.TemporaryDirectory(prefix="ed25519-blake2-asan-") as temporary:
            stage = Path(temporary)
            objects = library_objects("macosx", target, "-O1", stage)
            for objc, kind, plan in ((False, "native", native), (True, "wrappers", wrappers)):
                operations = stage / f"{kind}.txt"
                plan.write(operations)
                binary = source_link("macosx", target, "-O1", objects, stage / kind, objc)
                result = subprocess.run([str(binary), str(operations)], capture_output=True, text=True)
                if result.returncode:
                    print(result.stderr, file=sys.stderr)
                    raise SystemExit(f"{kind}: AddressSanitizer harness exited {result.returncode}")
                outputs = {"host-asan": result.stdout.splitlines()}
                problems = check(kind, plan, outputs, "host-asan")
                if problems:
                    raise SystemExit("\n".join(problems))
                print(f"{kind}: {len(plan.lines)} operations "
                      f"({sum(e is not None for e in plan.expected)} with independent results) "
                      "passed with AddressSanitizer")
        return 0
    device, runtime = simulator_device(args.device, "arm64")
    if device is None:
        raise SystemExit("No available arm64 iOS simulator")
    x86_device, x86_runtime = simulator_device(args.x86_device, "x86_64")

    with tempfile.TemporaryDirectory(prefix="ed25519-blake2-native-") as temporary:
        stage = Path(temporary)
        native.write(stage / "native.txt")
        wrappers.write(stage / "wrappers.txt")
        binaries = legacy_slices(vectors, stage / "legacy")

        builds = {}
        for label, sdk, target, optimization, arch in (
                ("new-O0-arm64", "iphonesimulator", SIMULATOR["arm64"], "-O0", None),
                ("new-Os-arm64", "iphonesimulator", SIMULATOR["arm64"], "-Os", None),
                ("new-Os-x86_64", "iphonesimulator", SIMULATOR["x86_64"], "-Os", "x86_64"),
                ("new-Os-device", "iphoneos", DEVICE, "-Os", None)):
            folder = stage / label
            folder.mkdir()
            builds[label] = (sdk, target, optimization, arch, library_objects(sdk, target, optimization, folder))
        if args.xcode_products:
            builds["xcode-arm64"] = ("iphonesimulator", SIMULATOR["arm64"], "-Os", None,
                                     [str(args.xcode_products / "libed25519.o"),
                                      str(args.xcode_products / "blake2lib.o")])

        runnable, linked = {}, []
        for objc, kind in ((False, "native"), (True, "wrappers")):
            runnable[(kind, "old-arm64")] = (legacy_link(
                "iphonesimulator", SIMULATOR["arm64"], "ios-arm64_x86_64-simulator", binaries,
                stage / f"{kind}-old-arm64", objc), None)
            linked.append(legacy_link("iphoneos", DEVICE, "ios-arm64", binaries, stage / f"{kind}-old-device", objc))
            for label, (sdk, target, optimization, arch, objects) in builds.items():
                binary = source_link(sdk, target, optimization, objects, stage / f"{kind}-{label}", objc)
                if sdk == "iphoneos":
                    linked.append(binary)
                else:
                    runnable[(kind, label)] = (binary, arch)

        problems, skipped = [], []
        for kind, plan in (("native", native), ("wrappers", wrappers)):
            outputs = {}
            for (harness_kind, label), (binary, arch) in runnable.items():
                if harness_kind != kind:
                    continue
                if arch == "x86_64" and x86_device is None:
                    skipped.append(f"{kind}/{label}: no installed iOS simulator runtime runs x86_64")
                    continue
                lines, error = execute(x86_device if arch == "x86_64" else device, binary, stage / f"{kind}.txt")
                if lines is None:
                    raise SystemExit(f"{kind}/{label} failed in the simulator: {error}")
                outputs[label] = lines
            problems += check(kind, plan, outputs, "old-arm64")
            if kind == "native" and "old-arm64" in outputs:
                results = outputs["old-arm64"]
                for group, digest in vectors["blake2_kat"]["digests"].items():
                    produced = b"".join(bytes.fromhex(results[index].split()[1]) for index in native.groups[group])
                    if hashlib.sha256(produced).hexdigest() != digest:
                        problems.append(f"BLAKE2 KAT {group} does not match the official digests")
            print(f"{kind}: {len(plan.lines)} operations ({sum(e is not None for e in plan.expected)} with "
                  f"independent results) run by {', '.join(sorted(outputs))}")

    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 1
    print(f"arm64 executed in {runtime} ({device})")
    if x86_device:
        print(f"x86_64 executed in {x86_runtime} ({x86_device})")
    print(f"Linked for device arm64 only: {len(linked)} harnesses")
    for line in skipped:
        print(f"Linked but not executed: {line}")
    print("Every build printed what the replaced binaries print, and every independent result matched")
    return 0


if __name__ == "__main__":
    sys.exit(main())
