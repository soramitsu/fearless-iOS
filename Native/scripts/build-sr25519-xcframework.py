#!/usr/bin/env python3
"""Build the checked SR25519 static XCFramework from pinned Rust source."""

import argparse
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
    is_macos = supported_platform == "MacOSX"
    content = folder / "Versions" / "A" if is_macos else folder
    headers = content / "Headers"
    modules = content / "Modules"
    headers.mkdir(parents=True)
    modules.mkdir()
    shutil.copy2(archive, content / "sr25519lib")
    if simulator_sidecar:
        shutil.copy2(archive, content / "libsr25519crust.a")
    shutil.copy2(CRATE / "include" / "sr25519" / "sr25519.h", headers / "sr25519.h")
    shutil.copy2(ROOT / "native" / "sr25519lib.h", headers / "sr25519lib.h")
    (modules / "module.modulemap").write_text(MODULE_MAP)
    bundle_info = {
        "CFBundleExecutable": "sr25519lib",
        "CFBundleIdentifier": "co.jp.soramitsu.sr25519lib",
        "CFBundleName": "sr25519lib",
        "CFBundlePackageType": "FMWK",
        "CFBundleShortVersionString": "1.0",
        "CFBundleSupportedPlatforms": [supported_platform],
        "CFBundleVersion": "1",
        "MinimumOSVersion": min_version,
    }
    if is_macos:
        (content / "Resources").mkdir()
        bundle_info["LSMinimumSystemVersion"] = min_version
        write_plist(content / "Resources" / "Info.plist", bundle_info)
        (folder / "Versions" / "Current").symlink_to("A")
        for name in ("Headers", "Modules", "Resources", "sr25519lib"):
            (folder / name).symlink_to(Path("Versions/Current") / name)
    else:
        write_plist(content / "Info.plist", bundle_info)
    run("codesign", "--force", "--sign", "-", "--timestamp=none", str(folder))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--add-macos-slice", action="store_true",
                        help="Only replace the macOS slice and update the outer plist.")
    args = parser.parse_args()
    macos_targets = {
        "aarch64-apple-darwin": ("macosx", "arm64"),
        "x86_64-apple-darwin": ("macosx", "x86_64"),
    }
    targets = {} if args.add_macos_slice else {
        "aarch64-apple-ios": ("iphoneos", "arm64"),
        "aarch64-apple-ios-sim": ("iphonesimulator", "arm64"),
        "x86_64-apple-ios": ("iphonesimulator", "x86_64"),
    }
    targets.update(macos_targets)
    env = os.environ.copy()
    env["MACOSX_DEPLOYMENT_TARGET"] = "14.0"
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
            minimum_flag = {
                "iphoneos": "-miphoneos-version-min=14.0",
                "iphonesimulator": "-mios-simulator-version-min=14.0",
                "macosx": "-mmacosx-version-min=14.0",
            }[sdk]
            run("xcrun", "--sdk", sdk, "clang", "-arch", arch,
                "-isysroot", sdk_path, minimum_flag,
                "-c", str(ROOT / "native" / "sr25519lib_vers.c"), "-o", str(stub))
            archive = stage / (target + ".a")
            rust_archive = target_dir / target / "release" / "libsr25519crust.a"
            run("xcrun", "libtool", "-static", "-D", "-o", str(archive),
                str(rust_archive), str(stub))
            thin_archives[target] = archive

        package = stage / "sr25519lib.xcframework"
        macos_id = "macos-arm64_x86_64"
        macos_archive = stage / "macos.a"
        run("xcrun", "lipo", "-create", "-output", str(macos_archive),
            *(str(thin_archives[target]) for target in macos_targets))
        framework(package, macos_id, macos_archive, "MacOSX", "14.0")
        macos_library = {
            "BinaryPath": f"{FRAMEWORK}/Versions/A/sr25519lib",
            "LibraryIdentifier": macos_id,
            "LibraryPath": FRAMEWORK,
            "SupportedArchitectures": ["arm64", "x86_64"],
            "SupportedPlatform": "macos",
        }
        if args.add_macos_slice:
            with (OUTPUT / "Info.plist").open("rb") as source:
                info = plistlib.load(source)
            info["AvailableLibraries"] = [
                lib for lib in info["AvailableLibraries"]
                if lib["LibraryIdentifier"] != macos_id
            ] + [macos_library]
            if (OUTPUT / macos_id).exists():
                shutil.rmtree(OUTPUT / macos_id)
            shutil.move(str(package / macos_id), str(OUTPUT / macos_id))
            write_plist(OUTPUT / "Info.plist", info)
            return

        simulator_archive = stage / "simulator.a"
        run("xcrun", "lipo", "-create", "-output", str(simulator_archive),
            str(thin_archives["aarch64-apple-ios-sim"]),
            str(thin_archives["x86_64-apple-ios"]))

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
                macos_library,
            ],
            "CFBundlePackageType": "XFWK",
            "XCFrameworkFormatVersion": "1.0",
        })
        shutil.rmtree(OUTPUT)
        shutil.move(str(package), str(OUTPUT))


if __name__ == "__main__":
    main()
