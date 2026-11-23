#!/usr/bin/env python3
"""Link and exercise the packaged SR25519 library on iOS or macOS."""

import argparse
import json
import platform
import plistlib
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
TESTS = ROOT / "Tests" / "SR25519Native"
ARTIFACT = ROOT / "Binaries" / "sr25519lib.xcframework"
SIMULATOR = ARTIFACT / "ios-arm64_x86_64-simulator" / "sr25519lib.framework"
DEVICE = ARTIFACT / "ios-arm64" / "sr25519lib.framework"


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True)


def compile_harness(sdk, arch, framework, output, source, objc=False):
    minimum = {
        "iphoneos": "-miphoneos-version-min=14.0",
        "iphonesimulator": "-mios-simulator-version-min=14.0",
        "macosx": "-mmacosx-version-min=14.0",
    }[sdk]
    command = ["xcrun", "--sdk", sdk, "clang", "-arch", arch, minimum,
               "-F", str(framework.parent), "-I", str(framework / "Headers"),
               "-I", str(ROOT / "Sources" / "IrohaCrypto" / "include"),
               "-DCHECKED_SIGN", str(source)]
    if objc:
        command.insert(4, "-fobjc-arc")
        command.extend(str(ROOT / "Sources" / "IrohaCrypto" / "Classes" / "sr25519" / name)
                       for name in ("SNSigner.m", "SNKeyFactory.m", "SNKeypair.m",
                                    "SNPrivateKey.m", "SNPublicKey.m", "SNSignature.m",
                                    "SNSignatureVerifier.m"))
    command.extend([str(framework / "sr25519lib"), "-o", str(output),
                    "-framework", "Foundation", "-framework", "Security"])
    run(*command)


def simulator_id():
    inventory = json.loads(run("xcrun", "simctl", "list", "devices", "available", "--json").stdout)
    for devices in inventory["devices"].values():
        for device in devices:
            if device.get("isAvailable") and device.get("udid"):
                return device["udid"]
    raise RuntimeError("No available iOS simulator for SR25519 runtime checks")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--macos-only", action="store_true",
                        help="Link both Mac architectures and execute on the host.")
    parser.add_argument("--compare-baseline", type=Path,
                        help="Previous sr25519lib.xcframework for cross-signature checks")
    args = parser.parse_args()
    vectors = json.loads((TESTS / "legacy-vectors.json").read_text())
    with tempfile.TemporaryDirectory(prefix="sr25519-native-test-") as directory:
        stage = Path(directory)
        if args.macos_only:
            identifier = "macos-arm64_x86_64"
            framework = ARTIFACT / identifier / "sr25519lib.framework"
            with (ARTIFACT / "Info.plist").open("rb") as stream:
                libraries = plistlib.load(stream)["AvailableLibraries"]
            library, = (lib for lib in libraries if lib["LibraryIdentifier"] == identifier)
            assert library["SupportedPlatform"] == "macos"
            assert set(library["SupportedArchitectures"]) == {"arm64", "x86_64"}
            assert (ARTIFACT / identifier / library["BinaryPath"]).samefile(framework / "sr25519lib")
            with (framework / "Resources/Info.plist").open("rb") as stream:
                info = plistlib.load(stream)
            assert info["CFBundleSupportedPlatforms"] == ["MacOSX"]
            assert info["MinimumOSVersion"] == info["LSMinimumSystemVersion"] == "14.0"
            for name in ("Resources", "Modules", "Headers", "sr25519lib", "Versions/Current"):
                assert (framework / name).is_symlink()
            for arch in library["SupportedArchitectures"]:
                compile_harness("macosx", arch, framework, stage / f"parity-{arch}",
                                TESTS / "sr25519_parity.c")
                compile_harness("macosx", arch, framework, stage / f"signer-{arch}",
                                TESTS / "signer_boundary.m", objc=True)
            arch = platform.machine()
            output = run(str(stage / f"parity-{arch}"), vectors["old_signature"]).stdout
            print(run(str(stage / f"signer-{arch}")).stdout.strip())
            print(f"Linked macOS arm64 and x86_64, executed on {arch}")
        else:
            for sdk, arch, framework in (
                ("iphoneos", "arm64", DEVICE),
                ("iphonesimulator", "arm64", SIMULATOR),
                ("iphonesimulator", "x86_64", SIMULATOR),
            ):
                compile_harness(sdk, arch, framework,
                                stage / f"parity-{sdk}-{arch}",
                                TESTS / "sr25519_parity.c")
                compile_harness(sdk, arch, framework,
                                stage / f"signer-{sdk}-{arch}",
                                TESTS / "signer_boundary.m", objc=True)

            device = simulator_id()
            output = run("xcrun", "simctl", "spawn", "-s", device,
                         str(stage / "parity-iphonesimulator-arm64"),
                         vectors["old_signature"]).stdout
        actual = dict(line.split("=", 1) for line in output.strip().splitlines())
        for key in ("pair", "hard", "public_soft", "ed", "converted"):
            assert actual[key] == vectors[key], key
        assert actual["soft"][:64] == vectors["soft_scalar"]
        assert actual["soft"][-64:] == vectors["public_soft"]
        assert actual["checked"] == "00" * 64

        if args.macos_only:
            print("macOS bundle, SR25519 legacy derivation and signing vectors passed")
            return

        if args.compare_baseline:
            baseline = (args.compare_baseline.resolve() /
                        "ios-arm64_x86_64-simulator" / "sr25519lib.framework")
            baseline_binary = stage / "parity-baseline-arm64"
            compile_harness("iphonesimulator", "arm64", baseline,
                            baseline_binary, TESTS / "sr25519_parity.c")
            # Each harness exits unsuccessfully if its supplied signature fails
            # verification; signatures themselves are randomized.
            previous_output = run("xcrun", "simctl", "spawn", "-s", device,
                                  str(baseline_binary), actual["signature"]).stdout
            previous = dict(line.split("=", 1) for line in previous_output.strip().splitlines())
            run("xcrun", "simctl", "spawn", "-s", device,
                str(stage / "parity-iphonesimulator-arm64"), previous["signature"])
            print("Previous and current libraries verified one another's signatures")

        result = run("xcrun", "simctl", "spawn", "-s", device,
                     str(stage / "signer-iphonesimulator-arm64"))
        print(result.stdout.strip())
        print("SR25519 legacy vectors, checked errors, and iOS slice linkage passed")
        print("Device arm64 and simulator x86_64 were linked; execution used simulator arm64")


if __name__ == "__main__":
    main()
