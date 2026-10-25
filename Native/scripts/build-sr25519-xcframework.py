#!/usr/bin/env python3
"""Build the checked SR25519 static XCFramework from pinned Rust source."""

import os
import plistlib
import shutil
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
CRATE = ROOT / "native" / "sr25519crust"
OUTPUT = ROOT / "Binaries" / "sr25519lib.xcframework"
FRAMEWORK = "sr25519lib.framework"
MODULE_MAP = "framework module sr25519lib {\n  umbrella header \"sr25519lib.h\"\n  export *\n\n  module * { export * }\n}\n"


def run(*args, **kwargs):
    subprocess.run(args, check=True, **kwargs)


def write_plist(path, data):
    with path.open("wb") as output:
        plistlib.dump(data, output, sort_keys=True)


def framework(stage, identifier, archive, supported_platform, min_version,
              simulator_sidecar=False):
    folder = stage / identifier / FRAMEWORK
    headers = folder / "Headers"
    modules = folder / "Modules"
    headers.mkdir(parents=True)
    modules.mkdir()
    shutil.copy2(archive, folder / "sr25519lib")
    if simulator_sidecar:
        shutil.copy2(archive, folder / "libsr25519crust.a")
    shutil.copy2(CRATE / "include" / "sr25519" / "sr25519.h", headers / "sr25519.h")
    shutil.copy2(ROOT / "native" / "sr25519lib.h", headers / "sr25519lib.h")
    (modules / "module.modulemap").write_text(MODULE_MAP)
    write_plist(folder / "Info.plist", {
        "CFBundleExecutable": "sr25519lib",
        "CFBundleIdentifier": "co.jp.soramitsu.sr25519lib",
        "CFBundleName": "sr25519lib",
        "CFBundlePackageType": "FMWK",
        "CFBundleShortVersionString": "1.0",
        "CFBundleSupportedPlatforms": [supported_platform],
        "CFBundleVersion": "1",
        "MinimumOSVersion": min_version,
    })
    run("codesign", "--force", "--sign", "-", "--timestamp=none", str(folder))


def main():
    targets = {
        "aarch64-apple-ios": ("iphoneos", "arm64"),
        "aarch64-apple-ios-sim": ("iphonesimulator", "arm64"),
        "x86_64-apple-ios": ("iphonesimulator", "x86_64"),
    }
    env = os.environ.copy()
    env["IPHONEOS_DEPLOYMENT_TARGET"] = "14.0"
    for target in targets:
        run("cargo", "build", "--release", "--locked", "--target", target,
            cwd=CRATE, env=env)

    target_dir = Path(env.get("CARGO_TARGET_DIR", CRATE / "target"))
    with tempfile.TemporaryDirectory(prefix="sr25519-xcframework-") as temp:
        stage = Path(temp)
        thin_archives = {}
        for target, (sdk, arch) in targets.items():
            sdk_path = subprocess.check_output(
                ["xcrun", "--sdk", sdk, "--show-sdk-path"], text=True).strip()
            stub = stage / (target + "-vers.o")
            minimum_flag = ("-miphoneos-version-min=14.0" if sdk == "iphoneos"
                            else "-mios-simulator-version-min=14.0")
            run("xcrun", "--sdk", sdk, "clang", "-arch", arch,
                "-isysroot", sdk_path, minimum_flag,
                "-c", str(ROOT / "native" / "sr25519lib_vers.c"), "-o", str(stub))
            archive = stage / (target + ".a")
            rust_archive = target_dir / target / "release" / "libsr25519crust.a"
            run("xcrun", "libtool", "-static", "-D", "-o", str(archive),
                str(rust_archive), str(stub))
            thin_archives[target] = archive

        simulator_archive = stage / "simulator.a"
        run("xcrun", "lipo", "-create", "-output", str(simulator_archive),
            str(thin_archives["aarch64-apple-ios-sim"]),
            str(thin_archives["x86_64-apple-ios"]))

        package = stage / "sr25519lib.xcframework"
        framework(package, "ios-arm64", thin_archives["aarch64-apple-ios"],
                  "iPhoneOS", "14.0")
        framework(package, "ios-arm64_x86_64-simulator", simulator_archive,
                  "iPhoneSimulator", "14.0", simulator_sidecar=True)
        write_plist(package / "Info.plist", {
            "AvailableLibraries": [
                {
                    "BinaryPath": f"{FRAMEWORK}/sr25519lib",
                    "LibraryIdentifier": "ios-arm64",
                    "LibraryPath": FRAMEWORK,
                    "SupportedArchitectures": ["arm64"],
                    "SupportedPlatform": "ios",
                },
                {
                    "BinaryPath": f"{FRAMEWORK}/sr25519lib",
                    "LibraryIdentifier": "ios-arm64_x86_64-simulator",
                    "LibraryPath": FRAMEWORK,
                    "SupportedArchitectures": ["arm64", "x86_64"],
                    "SupportedPlatform": "ios",
                    "SupportedPlatformVariant": "simulator",
                },
            ],
            "CFBundlePackageType": "XFWK",
            "XCFrameworkFormatVersion": "1.0",
        })
        shutil.rmtree(OUTPUT)
        shutil.move(str(package), str(OUTPUT))


if __name__ == "__main__":
    main()
