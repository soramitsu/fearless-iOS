#!/usr/bin/env python3
"""Run the shipped and the pinned sr25519lib slices side by side and write the app fixture.

"Shipped" is `Binaries/sr25519lib.xcframework` at the shared-features-spm revision that
fearless-iOS tag 4.0.4 pins; "pinned" is the one in the resolved checkout. For both, the
device slice is retagged (see retag_device_archive.py) so its arm64 machine code runs
in an arm64 simulator process next to the simulator slice. The script

- derives the golden wallets with all four slices and compares them with the root
  golden catalog, @polkadot/util-crypto (@scure/sr25519) and sr25519_reference.py;
- signs with every slice from key material written by the shipped device slice,
  including soft-path keys and their random nonce, and verifies every signature with
  every slice and both independent implementations;
- records what the checked entry point refuses;
- writes fearlessTests/UpgradeFixtures/Crypto/sr25519-known-answers.v1.json, whose key
  material and "shipped" signatures come from the shipped device slice.

Nothing is fetched: the shipped binary is read from the package's git history.
"""
import argparse
import hashlib
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import sr25519_reference as reference  # noqa: E402

SHIPPED_REVISION = "53e0a4bbea854ab32e97392365c3e523b9a0dc66"
FRAMEWORK = "Binaries/sr25519lib.xcframework"
DEVICE = "ios-arm64/sr25519lib.framework/sr25519lib"
SIMULATOR = "ios-arm64_x86_64-simulator/sr25519lib.framework/sr25519lib"
SLICE_SHA256 = {
    ("shipped", "device"): "5a8a6a2cf08ffa66f071d4cefab159d51de8a49842bcd44f479b765f901c8886",
    ("shipped", "simulator"): "463048b6fd787ba0578c4d22de08d41f1ace34a4b638d564f11f38848bf3d3a3",
    ("pinned", "device"): "4af3fff90ef0e6fe87bd7528f71dc888ae974dac470f190a87f245f68f2682d4",
    ("pinned", "simulator"): "7cf16e0951f25f35f74b3b388bb219ad5a35b8ff9a97abd5473a5448396e3cba",
}
SLICES = [("shipped", "device"), ("shipped", "simulator"), ("pinned", "device"), ("pinned", "simulator")]
WRITER = ("shipped", "device")

ABANDON = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
LEGAL = "legal winner thank year wave sausage worth useful legal winner thank yellow"
# BIP39 entropy of the two published phrases; checked below against the golden public keys.
ENTROPY = {ABANDON: bytes(16), LEGAL: bytes([0x7F]) * 16}
ALICE_SEED = "e5be9a5092b81bca64be81d212e7f2f9eba183bb7a90954f7b76361f6edb5c0a"
JSON_PASSWORD = "Legacy-json-pässwörd"

WALLETS = [
    {"id": "GW-M1/root", "golden": "GW-M1", "import": "mnemonic", "mnemonic": ABANDON, "derivationPath": "",
     "goldenPublicKey": "GW-M1/sr25519/root/publicKey"},
    {"id": "GW-M4/hard-password", "golden": "GW-M4", "import": "mnemonic", "mnemonic": LEGAL,
     "derivationPath": "//polkadot//0///p@ss", "goldenPublicKey": "GW-M4/sr25519/hard-password/publicKey"},
    {"id": "GW-M5/hard-soft", "golden": "GW-M5", "import": "mnemonic", "mnemonic": ABANDON,
     "derivationPath": "//polkadot/0", "goldenPublicKey": "GW-M5/sr25519/hard-soft/publicKey"},
    {"id": "GW-M5/soft", "golden": "GW-M5", "import": "mnemonic", "mnemonic": ABANDON, "derivationPath": "/0",
     "goldenPublicKey": "GW-M5/sr25519/soft/publicKey"},
    {"id": "GW-S1/raw-seed", "golden": "GW-S1", "import": "seed", "seed": ALICE_SEED, "derivationPath": "",
     "goldenPublicKey": "GW-S1/sr25519/seed/publicKey"},
]
MESSAGES = {
    "empty": b"",
    "text": b"Fearless sr25519 known answer",
    "payloadHash": bytes.fromhex("9a3f6f3c8f5d0c1e2b4a6978504132241c0e7f6a5b4c3d2e1f00112233445566"),
    "longPayload": bytes(range(256)) + bytes(range(44)),
}
# Paths every Substrate implementation decodes the same way. The Android catalog also
# holds decoder edge cases ("//1/", "/", an overflowing number) that are Android-specific.
STANDARD_PATHS = ["", "//polkadot", "//kusama", "//polkadot/0", "/0", "/soft", "//1//2/3", "//hard/soft", "//0",
                  "//ポルカ/1"]


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run(*args, **kwargs):
    return subprocess.run([str(a) for a in args], check=True, capture_output=True, text=True, **kwargs)


def chaincode(name):
    if name.isdigit() and int(name) < 2 ** 64:
        data = int(name).to_bytes(8, "little")
    else:
        raw = name.encode()
        assert len(raw) < 64, "single-byte SCALE compact length only"
        data = bytes([len(raw) << 2]) + raw
    if len(data) > 32:
        data = hashlib.blake2b(data, digest_size=32).digest()
    return data.ljust(32, b"\0")


def junctions(path):
    body, _, password = path.partition("///")
    return password, [("hard" if slashes == "//" else "soft", chaincode(name))
                      for slashes, name in re.findall(r"(//?)([^/]+)", body)]


class Slice:
    """One sr25519lib archive linked into sr25519_tool and run in the simulator."""

    def __init__(self, label, tool, simulator, stage):
        self.label, self.tool, self.simulator, self.stage = label, tool, simulator, stage
        self.count = 0

    def call(self, *commands, check=True):
        self.count += 1
        script = self.stage / f"{self.label}-{self.count}.cmds"
        script.write_text("".join(" ".join(c) + "\n" for c in commands))
        result = subprocess.run(["xcrun", "simctl", "spawn", self.simulator, str(self.tool), str(script)],
                                capture_output=True, text=True)
        if check and result.returncode != 0:
            raise RuntimeError(f"{self.label}: {result.stderr}")
        lines = result.stdout.split("\n")[:-1]
        return lines if check else (result.returncode, lines)

    def derive(self, seed, steps):
        keypair = self.call(("fromseed", seed.hex()))[0]
        for kind, cc in steps:
            keypair = self.call((kind, keypair, cc.hex()))[0]
        return bytes.fromhex(keypair)


def message_arg(message):
    return message.hex() or "-"


def build_slices(args, stage):
    shipped = stage / "shipped"
    shipped.mkdir()
    archive = subprocess.run(["git", "-C", args.repository, "archive", SHIPPED_REVISION, FRAMEWORK],
                             check=True, capture_output=True).stdout
    subprocess.run(["tar", "-x", "-C", str(shipped)], input=archive, check=True)
    roots = {"shipped": shipped / FRAMEWORK, "pinned": Path(args.checkout) / FRAMEWORK}
    sdk = run("xcrun", "--sdk", "iphonesimulator", "--show-sdk-path").stdout.strip()
    slices, retag_log = {}, []
    for origin, kind in SLICES:
        source = roots[origin] / (DEVICE if kind == "device" else SIMULATOR)
        digest = sha256(source)
        assert digest == SLICE_SHA256[(origin, kind)], f"{origin} {kind} slice is {digest}"
        archive_path = source
        if kind == "device":
            archive_path = stage / f"{origin}-device-as-simulator.a"
            retag_log.append(run(sys.executable, HERE / "retag_device_archive.py", source, archive_path).stdout.strip())
        tool = stage / f"tool-{origin}-{kind}"
        run("xcrun", "--sdk", "iphonesimulator", "clang", "-arch", "arm64", "-mios-simulator-version-min=14.0",
            "-isysroot", sdk, "-O1", *(["-DCHECKED_SIGN"] if origin == "pinned" else []),
            HERE / "sr25519_tool.c", archive_path, "-framework", "Security", "-framework", "Foundation", "-o", tool)
        slices[(origin, kind)] = Slice(f"{origin}-{kind}", tool, args.simulator, stage)
    return slices, retag_log


def polkadot(args, stage, request):
    path = stage / f"polkadot-{len(list(stage.glob('polkadot-*.json')))}.json"
    path.write_text(json.dumps(request))
    return json.loads(run("node", HERE / "polkadot_reference.cjs", args.node_modules_owner, path).stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--checkout", required=True, help="resolved shared-features-spm checkout (pinned revision)")
    parser.add_argument("--repository", required=True, help="git repository holding the 4.0.4 pin " + SHIPPED_REVISION)
    parser.add_argument("--simulator", required=True, help="UDID of a booted arm64 iOS simulator")
    parser.add_argument("--node-modules-owner", required=True, help="directory whose node_modules has @polkadot/keyring")
    parser.add_argument("--golden", required=True, help="root config/upgrade-matrix/golden-wallets.v1.json")
    parser.add_argument("--android-vectors", required=True, help="android-parity vector directory")
    parser.add_argument("--out", required=True, help="fixture to write")
    parser.add_argument("--report", required=True, help="cross-check report to write")
    args = parser.parse_args()

    golden = {check["id"]: check for wallet in json.loads(Path(args.golden).read_text())["wallets"]
              for check in wallet["checks"]}
    report = {"checks": {}, "slices": {f"{o}-{k}": SLICE_SHA256[(o, k)] for o, k in SLICES}}

    def passed(name, count=1):
        report["checks"][name] = report["checks"].get(name, 0) + count

    with tempfile.TemporaryDirectory(prefix="sr25519-cross-check-") as directory:
        stage = Path(directory)
        slices, report["retag"] = build_slices(args, stage)
        writer = slices[WRITER]
        pinned = [slices[("pinned", "device")], slices[("pinned", "simulator")]]

        # --- golden wallets: derivation ------------------------------------------------
        reference_pairs = polkadot(args, stage, {
            "derive": [{"id": w["id"], "suri": w["mnemonic"] + w["derivationPath"]}
                       for w in WALLETS if w["import"] == "mnemonic"],
            "seeds": [{"id": w["id"], "seedHex": w["seed"]} for w in WALLETS if w["import"] == "seed"],
        })
        report["reference"] = reference_pairs["libraries"]
        by_id = {entry["id"]: entry for entry in reference_pairs["derive"]}
        wallets = []
        for wallet in WALLETS:
            password, steps = junctions(wallet["derivationPath"])
            if wallet["import"] == "mnemonic":
                mini = reference.substrate_mini_secret(ENTROPY[wallet["mnemonic"]], password)
            else:
                mini = bytes.fromhex(wallet["seed"])
            deterministic = not steps or steps[-1][0] == "hard"

            expected_secret = reference.secret_from_mini(mini)
            for kind, cc in steps:
                if kind == "hard":
                    expected_secret = reference.derive_hard(expected_secret, cc)
                else:
                    # The reference continues from its own scalar; the nonce plays no part in later steps.
                    expected_secret = reference.derive_soft_scalar(expected_secret, cc) + bytes(32)
            expected_public = reference.public_from_secret(expected_secret)
            assert expected_public.hex() == golden[wallet["goldenPublicKey"]]["reference"], wallet["id"]
            assert expected_public.hex() == by_id[wallet["id"]]["publicKey"], wallet["id"]
            passed("golden public key equals from-spec reference and @scure/sr25519")

            derived = {}
            for key, item in slices.items():
                keypair = item.derive(mini, steps)
                secret, public = keypair[:64], keypair[64:]
                assert public == expected_public, (wallet["id"], item.label)
                assert secret[:32] == expected_secret[:32], (wallet["id"], item.label)
                if deterministic:
                    assert secret == expected_secret, (wallet["id"], item.label)
                assert reference.public_from_secret(secret) == public
                ed = bytes.fromhex(item.call(("toed", secret.hex()))[0])
                assert ed == reference.to_ed25519_bytes(secret)
                assert ed[:32].hex() == by_id[wallet["id"]]["secretKeyEd25519"][:64], (wallet["id"], item.label)
                if deterministic:
                    assert ed.hex() == by_id[wallet["id"]]["secretKeyEd25519"], (wallet["id"], item.label)
                assert bytes.fromhex(item.call(("fromed", ed.hex()))[0]) == secret
                derived[key] = keypair
                passed("slice derivation equals golden catalog, from-spec reference and @scure/sr25519")
            if deterministic:
                assert len(set(derived.values())) == 1, wallet["id"]
                passed("deterministic key material is byte-identical across all four slices")
            else:
                nonces = {keypair[32:64] for keypair in derived.values()}
                nonces.add(writer.derive(mini, steps)[32:64])
                assert len(nonces) == len(derived) + 1, wallet["id"]
                parent = writer.derive(mini, steps[:-1])
                for item in slices.values():
                    child = item.call(("softpub", parent[64:].hex(), steps[-1][1].hex()))[0]
                    assert child == expected_public.hex()
                passed("soft-path nonce differs on every derivation while scalar and public key do not")

            wallets.append({
                **{k: v for k, v in wallet.items() if k != "goldenPublicKey"},
                "miniSecret": mini.hex(),
                "nonceDeterministic": deterministic,
                "stored": {"substrateSecretKey": derived[WRITER][:64].hex(),
                           "substratePublicKey": derived[WRITER][64:].hex()},
                "ss58": by_id[wallet["id"]]["ss58"],
                "goldenChecks": sorted(i for i, c in golden.items()
                                       if i.startswith(wallet["golden"] + "/sr25519/")
                                       and c["derive"].get("path", "") == wallet["derivationPath"]
                                       or i == wallet["goldenPublicKey"]),
                "signatures": [],
            })
            for check in wallets[-1]["goldenChecks"]:
                output = golden[check]["derive"]["output"]
                value = (expected_public.hex() if output == "publicKey"
                         else wallets[-1]["ss58"][str(golden[check]["derive"]["ss58Prefix"])])
                assert value == golden[check]["reference"], check
                passed("golden catalog check reproduced")

        # --- keystores -----------------------------------------------------------------
        exports = polkadot(args, stage, {
            "derive": [{"id": w["id"], "suri": w["mnemonic"] + w["derivationPath"]}
                       for w in WALLETS if w["id"] in ("GW-M1/root", "GW-M5/soft")],
            "exportJson": [{"id": "GW-M1/root", "password": JSON_PASSWORD, "name": "GW-J1"},
                           {"id": "GW-M5/soft", "password": JSON_PASSWORD, "name": "GW-J1 soft"}],
        })
        export_pairs = {entry["id"]: entry for entry in exports["derive"]}
        keystores = []
        for export, name in zip(exports["exportJson"], ("GW-J1/sr25519", "GW-J1/sr25519-soft")):
            pair = export_pairs[export["id"]]
            # 4.0.4 stored what sr25519_from_ed25519_bytes returned for the PKCS8 secret inside
            # the JSON. That secret is read back from the JSON: for a soft junction its nonce is
            # not the one a separate derivation of the same path draws.
            stored = writer.call(("fromed", export["secretKeyEd25519"]))[0]
            for item in slices.values():
                assert item.call(("fromed", export["secretKeyEd25519"]))[0] == stored
            assert reference.public_from_secret(bytes.fromhex(stored)).hex() == pair["publicKey"]
            assert bytes.fromhex(stored) == reference.from_ed25519_bytes(bytes.fromhex(export["secretKeyEd25519"]))
            wallet_secret = next(w for w in wallets if w["id"] == export["id"])["stored"]["substrateSecretKey"]
            assert stored[:64] == wallet_secret[:64], export["id"]  # same scalar as the phrase import
            if export["id"] == "GW-M1/root":
                assert stored == wallets[0]["stored"]["substrateSecretKey"]
            keystores.append({
                "id": name, "of": export["id"],
                "writer": f"@polkadot/keyring {exports['libraries']['@polkadot/keyring']} toJson",
                "password": export["password"], "json": json.dumps(export["json"], separators=(",", ":")),
                "stored": {"substrateSecretKey": stored, "substratePublicKey": pair["publicKey"]},
            })
            passed("polkadot-js export converts to the same stored key on all four slices")

        android = json.loads((Path(args.android_vectors) / "07-json-keyring.json").read_text())
        for vector in android["vectors"]:
            if "sr25519" not in vector["input"].lower():
                continue
            entry = {"id": "android-parity/" + vector["input"].removesuffix(".json"),
                     "writer": vector.get("source", "Fearless Android 4.2.0 JsonSeedEncoder"),
                     "password": vector["password"], "json": vector["json"]}
            if "error" in vector["expected"]:
                entry["rejected"] = True
            else:
                pair = vector["expected"]["keypair"]
                entry["stored"] = {"substrateSecretKey": pair["privateKey"][2:] + pair["nonce"][2:],
                                   "substratePublicKey": pair["publicKey"][2:]}
                stored = bytes.fromhex(entry["stored"]["substrateSecretKey"])
                assert reference.public_from_secret(stored).hex() == entry["stored"]["substratePublicKey"]
                decoded = polkadot(args, stage, {"decodeJson": [{"json": json.loads(vector["json"]),
                                                               "password": vector["password"]}]})["decodeJson"][0]
                assert decoded["publicKey"] == entry["stored"]["substratePublicKey"]
                assert reference.from_ed25519_bytes(bytes.fromhex(decoded["secretKeyEd25519"])) == stored
                passed("Android parity keystore decodes to the recorded key in the references")
            keystores.append(entry)

        # --- signing -------------------------------------------------------------------
        stored_keys = [(w["id"], w["stored"]) for w in wallets] + \
                      [(k["id"], k["stored"]) for k in keystores if "stored" in k]
        signatures = []  # (key id, public, message name, signer label, signature hex)
        for key_id, stored in stored_keys:
            secret, public = stored["substrateSecretKey"], stored["substratePublicKey"]
            for name, message in MESSAGES.items():
                for item in slices.values():
                    signatures.append((key_id, public, name, item.label,
                                       item.call(("sign", public, secret, message_arg(message)))[0]))
                for item in pinned:
                    code, signature = item.call(("signchecked", public, secret, message_arg(message)))[0].split()
                    assert code == "0", (key_id, name, item.label, code)
                    signatures.append((key_id, public, name, item.label + "-checked", signature))
                    passed("checked entry point signs from key material the shipped device slice wrote")
        signed = polkadot(args, stage, {
            "derive": [{"id": w["id"], "suri": w["mnemonic"] + w["derivationPath"]}
                       for w in WALLETS if w["import"] == "mnemonic"],
            "seeds": [{"id": w["id"], "seedHex": w["seed"]} for w in WALLETS if w["import"] == "seed"],
            "sign": [{"id": w["id"], "messageHex": m.hex()} for w in WALLETS for m in MESSAGES.values()],
        })
        names = {message.hex(): name for name, message in MESSAGES.items()}
        publics = {w["id"]: w["stored"]["substratePublicKey"] for w in wallets}
        for entry in signed["sign"]:
            signatures.append((entry["id"], publics[entry["id"]], names[entry["messageHex"]], "reference",
                               entry["signature"]))

        for item in slices.values():
            results = item.call(*[("verify", s, message_arg(MESSAGES[m]), p) for _, p, m, _, s in signatures])
            assert results == ["1"] * len(signatures), item.label
            passed(f"signatures verified by {item.label}", len(signatures))
        for _, public, name, _, signature in signatures:
            assert reference.verify(bytes.fromhex(signature), MESSAGES[name], bytes.fromhex(public))
        passed("signatures verified by the from-spec reference", len(signatures))
        verified = polkadot(args, stage, {"verify": [{"publicKey": p, "messageHex": MESSAGES[m].hex(), "signature": s}
                                                     for _, p, m, _, s in signatures]})["verify"]
        assert verified == [True] * len(signatures)
        passed("signatures verified by @scure/sr25519", len(signatures))

        tampered = []
        for _, public, name, _, signature in signatures[::7]:
            flipped = bytearray(bytes.fromhex(signature))
            flipped[5] ^= 0x01
            tampered.append((flipped.hex(), MESSAGES[name] + b"\0", public))
            tampered.append((signature, MESSAGES[name] + b"\0", public))
            tampered.append((flipped.hex(), MESSAGES[name], public))
        for item in slices.values():
            assert item.call(*[("verify", s, message_arg(m), p) for s, m, p in tampered]) == ["0"] * len(tampered)
        assert not any(reference.verify(bytes.fromhex(s), m, bytes.fromhex(p)) for s, m, p in tampered)
        passed("tampered signatures and messages rejected by every verifier", len(tampered))

        for wallet in wallets:
            for key_id, _, name, signer, signature in signatures:
                if key_id == wallet["id"] and signer in (writer.label, "reference"):
                    wallet["signatures"].append({"message": name,
                                                 "writer": "shipped" if signer == writer.label else "reference",
                                                 "signature": signature})

        # --- what the checked entry point refuses -------------------------------------
        root, alice = wallets[0]["stored"], wallets[4]["stored"]
        group_order = reference.L.to_bytes(32, "little").hex()
        refused = [
            {"id": "mismatched-keypair", "signerError": 4,
             "substrateSecretKey": root["substrateSecretKey"], "substratePublicKey": alice["substratePublicKey"]},
            {"id": "non-canonical-secret", "signerError": 2,
             "substrateSecretKey": group_order + root["substrateSecretKey"][64:],
             "substratePublicKey": root["substratePublicKey"]},
            {"id": "invalid-public", "signerError": 3,
             "substrateSecretKey": root["substrateSecretKey"], "substratePublicKey": "01" + "00" * 31},
        ]
        text = MESSAGES["text"]
        for entry in refused:
            for item in pinned:
                code, output = item.call(("signchecked", entry["substratePublicKey"], entry["substrateSecretKey"],
                                          message_arg(text)))[0].split()
                assert (int(code), output) == (entry["signerError"], "00" * 64), (entry["id"], item.label)
                passed("checked entry point refuses with a status and a zeroed buffer")
        # The unchecked call 4.0.4 used never refused: a mismatched pair produced a signature no
        # verifier accepts, and an unparsable key aborted the process.
        report["shippedUncheckedBehaviour"] = {}
        for origin in ("shipped", "pinned"):
            item = slices[(origin, "device")]
            mismatch = refused[0]
            signature = item.call(("sign", mismatch["substratePublicKey"], mismatch["substrateSecretKey"],
                                   message_arg(text)))[0]
            assert not reference.verify(bytes.fromhex(signature), text, bytes.fromhex(mismatch["substratePublicKey"]))
            assert not reference.verify(bytes.fromhex(signature), text, bytes.fromhex(root["substratePublicKey"]))
            outcomes = {"mismatched-keypair": "returned a signature that verifies under neither key"}
            for entry in refused[1:]:
                status, _ = item.call(("sign", entry["substratePublicKey"], entry["substrateSecretKey"],
                                       message_arg(text)), check=False)
                assert status != 0, (origin, entry["id"])
                outcomes[entry["id"]] = f"process aborted (exit status {status})"
            report["shippedUncheckedBehaviour"][item.label] = outcomes

        # --- cross-platform derivation vectors ----------------------------------------
        keypairs = json.loads((Path(args.android_vectors) / "05-keypairs.json").read_text())
        decoded = {v["path"]: v["expected"] for v in
                   json.loads((Path(args.android_vectors) / "04-junctions.json").read_text())["vectors"]
                   if v["decoder"] == "substrate"}
        derivations = []
        for vector in keypairs["vectors"]:
            if vector.get("cryptoType") != "SR25519" or vector["kind"] != "substrate":
                continue
            if vector["path"] not in STANDARD_PATHS:
                continue
            _, steps = junctions(vector["path"])
            if vector["path"]:
                assert [(k.upper(), "0x" + cc.hex()) for k, cc in steps] == \
                    [(j["type"], j["chaincode"]) for j in decoded[vector["path"]]["junctions"]], vector["path"]
            expected = vector["expected"]
            for item in slices.values():
                keypair = item.derive(bytes.fromhex(vector["seed"][2:]), steps)
                assert keypair[:32].hex() == expected["privateKey"][2:], (vector["path"], item.label)
                assert keypair[64:].hex() == expected["publicKey"][2:], (vector["path"], item.label)
                assert (keypair[32:64].hex() == expected["nonce"][2:]) if vector["nonceDeterministic"] \
                    else expected["nonce"] is None
                passed("Android production-parity derivation vector reproduced")
            derivations.append({"seed": vector["seed"][2:], "path": vector["path"],
                                "secretScalar": expected["privateKey"][2:],
                                "nonce": expected["nonce"][2:] if expected["nonce"] else None,
                                "publicKey": expected["publicKey"][2:]})

    fixture = {
        "format": "fearless.ios.sr25519-known-answers",
        "version": 1,
        "warning": "Every secret in this file is a published test vector. Never fund these wallets.",
        "generatedBy": "scripts/deps/sr25519-provenance/cross-check-slices.py",
        "writer": {
            "description": "Stored keys and 'shipped' signatures were produced by the device slice of "
                           "sr25519lib.xcframework at the shared-features-spm revision that fearless-iOS tag 4.0.4 "
                           "pins, executed in an arm64 simulator process.",
            "sharedFeaturesRevision": SHIPPED_REVISION,
            "deviceSliceSha256": SLICE_SHA256[("shipped", "device")],
        },
        "reference": {**report["reference"],
                      "goldenWalletsSha256": sha256(args.golden),
                      "androidParityKeypairsSha256": sha256(Path(args.android_vectors) / "05-keypairs.json"),
                      "androidParityKeystoresSha256": sha256(Path(args.android_vectors) / "07-json-keyring.json")},
        "signingContext": reference.SIGNING_CONTEXT.decode(),
        "messages": {name: message.hex() for name, message in MESSAGES.items()},
        "wallets": wallets,
        "refused": refused,
        "derivations": derivations,
        "keystores": keystores,
    }
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(fixture, indent=1, ensure_ascii=False) + "\n")
    report["fixtureSha256"] = sha256(args.out)
    report["counts"] = {"wallets": len(wallets), "keystores": len(keystores), "derivations": len(derivations),
                        "signatures": len(signatures)}
    Path(args.report).write_text(json.dumps(report, indent=1) + "\n")
    print(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
