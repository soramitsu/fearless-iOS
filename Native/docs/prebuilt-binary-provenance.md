# Prebuilt binary provenance

Three of the wallet's native binaries were already accounted for:

- `sr25519lib` is rebuilt from pinned Rust source; see
  [sr25519-native-signing.md](sr25519-native-signing.md).
- `libed25519` and `blake2lib` are now built from pinned C sources; see
  [ed25519-blake2-native-provenance.md](ed25519-blake2-native-provenance.md).

`sorawallet.xcframework`, a closed-source Kotlin/Native framework built in
February 2024 from an unpublished revision of `soramitsu/x-networking`, was
removed on 2026-11-07. The wallet used it only to read Polkaswap pool
strategic-bonus APY. That query is now plain Swift in
`Sources/SSFPolkaswap/PolkaswapAPYWorker.swift`, sent to the Soramitsu indexer
(`https://pi.soramitsu.io/graphql`) that the wallet already uses for SORA
prices. The framework's configured SubQuery endpoint
(`api.subquery.network/sq/sora-xor/sora-prod`) answered HTTP 503 on that date.

The prebuilt `yttrium` libraries (`libyttrium.xcframework` and
`libyttrium-utils.xcframework`) that came in through `reown-swift` were removed
with it on 2026-11-07: `reown-swift` is under the WalletConnect Community
License, which is not open source. The wallet now speaks WalletConnect with its
own open-source client, `Packages/FearlessWalletConnect` (see
`docs/walletconnect-protocol.md`), which uses only Apple's system frameworks.

## macOS sr25519 framework

The macOS 14 static framework contains arm64 and x86_64 archives from the same
Apache-2.0 sr25519 crate, Cargo.lock and Rust 1.97.1 toolchain as iOS. The
crate uses the wallet's existing C ABI. Each architecture includes the
framework version symbols from `native/sr25519lib_vers.c`. The universal
archive has SHA-256
`201f93acf248ba4638d94f3e555a6f5163228d8e9d4072806c8d64a320fe7d06`.
The versioned framework uses relative bundle symlinks and an ad hoc code
signature. The two iOS directories retain the same SHA-256 for all 19 files.

From `Native/`, run these commands on a Mac with Xcode and the pinned Rust
toolchain installed. The first command adds or replaces only the macOS slice
and its outer plist entry. Omit its flag for a complete platform rebuild.

```sh
CARGO_TARGET_DIR="$PWD/.build-codex/rust" python3 scripts/build-sr25519-xcframework.py --add-macos-slice
python3 scripts/test-sr25519-native.py --macos-only
```

The test links the C and Objective-C harnesses for both architectures and
runs them on the host architecture. It checks the framework layout and
deployment floor, legacy keypair and derivation vectors, signature verification
and the Objective-C signer's error handling. The recorded runs exercised
arm64 natively and x86_64 under Rosetta on the same Mac. To repeat the Intel
run with Apple's universal Python, use
`arch -x86_64 /usr/bin/python3 scripts/test-sr25519-native.py --macos-only`.

On this Xcode 27.2 host, dyld rejected LINKEDIT alignment in Rust host compiler
plugins linked against the 27.2 SDK. For a cold build use the installed
Command Line Tools 26.5 SDK for Cargo:

```sh
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
  CARGO_TARGET_DIR="$PWD/.build-codex/rust" \
  python3 scripts/build-sr25519-xcframework.py --add-macos-slice
```

From an empty Cargo target directory this produced the same SHA-256 digests
for all ten macOS framework files and the outer XCFramework plist. Xcode's
explicit `xcrun --sdk macosx` steps still use the active Xcode SDK. The file
digests and relative symlink destinations are recorded in
`config/native-sources.json`.
