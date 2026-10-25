# sr25519 native library: provenance and known-answer evidence (IK-13)

sr25519 is the default key type of every Substrate wallet in Fearless. The current
source pin in `config/shared-features-source.json` carries the reviewed native
upgrade introduced by shared-features-spm `7dc1460c113f38f7f47012ebc8d6adceb3ad8cb9`
([PR #87](https://github.com/soramitsu/shared-features-spm/pull/87)). It preserves
the checked signing ABI and wallet key derivation while upgrading Schnorrkel to
0.11.5, curve25519-dalek to 4.1.3 and rand to 0.8.8. cbindgen is pinned to 0.29.4.

The current executable archive hashes are:

| Slice | SHA-256 |
| --- | --- |
| Device arm64 | `4af3fff90ef0e6fe87bd7528f71dc888ae974dac470f190a87f245f68f2682d4` |
| Simulator arm64/x86_64 | `7cf16e0951f25f35f74b3b388bb219ad5a35b8ff9a97abd5473a5448396e3cba` |

The simulator sidecar archive has the same hash as its framework executable.
The source review checked all 13 public C/framework-version exports, unchanged
public declarations, repeated-build hashes, legacy derivation vectors and direct
old/new signature verification. The exact source commit passed native CI and a
consuming-app build with 31 selected wallet tests on 2026-10-23. These checks do
not qualify physical-device execution or a signed store release. The source
package's `docs/sr25519-native-signing.md` records its build and compatibility
checks. Pass the desired source revision as the third argument to
`reproduce-xcframework.sh` when reproducing these newer archives.

The records below describe the earlier `4323032` source-built archives. Their
historical hashes and results remain evidence for that revision, not the current
pin. The committed known-answer fixture contains keys and signatures from the
shipped 4.0.4 binary; running `Sr25519KnownAnswerTests` with the current app checks
that those stored keys still work with the native library actually linked.

## Historical binaries (4323032 comparison)

| | shipped (every release before 4.2.0) | initial 4323032 candidate |
| --- | --- | --- |
| shared-features-spm | every revision from `e254ba5` (2023-10-31) up to `4323032`: 3.7.4 `0dede8c`, 4.0.4 `53e0a4b`, tag 4.0.5 `b3e2bf1`, TestFlight 2026.9.6 `3ad0fe9` | `4323032` (2026-09-24) |
| device slice `ios-arm64/.../sr25519lib` | git blob `b373b5ba`, SHA-256 `5a8a6a2cf08ffa66f071d4cefab159d51de8a49842bcd44f479b765f901c8886` | SHA-256 `84479e09b314a608ff8e29156dc3f8cad76a1c4919aaf323e83508cbca1342dc` |
| simulator slice | git blob `3a59eaf0`, SHA-256 `463048b6fd787ba0578c4d22de08d41f1ace34a4b638d564f11f38848bf3d3a3` | SHA-256 `c550e3e71d86af24ee01825b63d8aae007739c9802d3573d0841ca4586d887ad` |
| built with | rustc 1.46.0-nightly (`7750c3d46` 2020-06-26), schnorrkel 0.9.1, on a machine whose Cargo home was `/Users/russel` (strings in the archive) | rustc 1.97.1 (`8bab26f4f` 2026-07-14), schnorrkel 0.9.1, on this machine (see below) |
| crates (from paths in the archive / `Cargo.lock`) | schnorrkel 0.9.1, curve25519-dalek 2.1.0, merlin 2.0.0, rand 0.7.3 | schnorrkel 0.9.1, curve25519-dalek 2.1.3, merlin 2.0.1, rand 0.7.3 |
| exported C entry points | 10 `sr25519_*` functions | the same 10 plus `sr25519_sign_checked` |
| reproducible from source | no: no source or build recipe for it exists in any repository we have | yes, byte for byte, with the recipe below |

## How the 4323032 xcframework was produced (reproduced)

The Rust source is in the package itself: `native/sr25519crust` (`Cargo.toml` pins
`schnorrkel = "=0.9.1"`, `Cargo.lock` pins every transitive crate by checksum,
`rust-toolchain.toml` names 1.97.1). `native/sr25519lib_vers.c` adds the framework version
symbols, and `scripts/build-sr25519-xcframework.py` builds the device (`aarch64-apple-ios`)
and simulator (`aarch64-apple-ios-sim`, `x86_64-apple-ios`) archives with
`IPHONEOS_DEPLOYMENT_TARGET=14.0`, links them with `libtool -static -D`, lipos the simulator
slices and signs both frameworks ad hoc. `docs/sr25519-native-signing.md` in the package
says the source is based on Warchant/sr25519-crust `2ec5e53`; that upstream claim was not
re-checked here (no network fetch), but the reproduction below ties the committed binary to
the source that is committed next to it.

`scripts/deps/sr25519-provenance/reproduce-xcframework.sh <shared-features-spm checkout> <empty dir>`
exports `native/`, `scripts/` and the framework at `4323032` with `git archive`, runs the
package's own build script, and compares every file of the result with the committed
xcframework. Results on 2026-10-11 (macOS 27.0.1 arm64, Xcode 27.0 27A266a, rustup 1.29.0):

| environment | device slice | simulator slice | every xcframework file |
| --- | --- | --- | --- |
| `RUSTUP_TOOLCHAIN=stable-aarch64-apple-darwin` (1.97.1) `CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1` `CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_CODEGEN_UNITS=1` | identical | identical | all 20 identical, including headers, plists and ad-hoc signatures |
| the same, but the toolchain from `rust-toolchain.toml` (`1.97.1-aarch64-apple-darwin`) | differs only in the `rand` object (40 bytes) and the symbol table | the same, per architecture | no (the two archives and their signatures) |
| as documented in the package (no environment) | differs | differs | no |

So the committed binaries are exactly what the committed Rust source produces, but with
settings that are not in the repository:

1. **Toolchain directory.** The archive embeds
   `/Users/takemiyamakoto/.rustup/toolchains/stable-aarch64-apple-darwin/lib/rustlib/src/rust/library/std/src/sync/once.rs`
   (a panic location inlined into the `rand` crate; the `stable` toolchain has the
   `rust-src` component, so rustc writes the local path instead of `/rustc/8bab26f4f…`).
   `stable` and `1.97.1` are the same compiler build (same `rustc` binary hash, same std
   rlibs), so the only effect is that 40-byte string in the `rand` object.
2. **Codegen units.** Every crate is one codegen unit, and the build-script/proc-macro
   (`build-override`) profile was changed as well: it changes the crate metadata hashes in
   the archive member names. Neither setting is in `Cargo.toml` or the build script.
3. **Cargo home.** Panic locations embed `/Users/takemiyamakoto/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/...`,
   so a byte-identical rebuild needs that Cargo home path (or a remap).
4. **Xcode** for the version stub: Xcode 27.0 reproduces it; the std objects inside the
   archive name Xcode 26.2 only because that is what built the Rust distribution's std.

The package's own claim that rerunning the documented commands gives identical hashes is
therefore true only in that environment. To make the recipe self-contained, the package
should add `[profile.release] codegen-units = 1` and `[profile.release.build-override]
codegen-units = 1` to `native/sr25519crust/Cargo.toml` and `--remap-path-prefix` for the
Cargo home and toolchain paths, then rebuild and re-pin; that changes the bytes, so it is
a separate dependency change with its own review. The current upgrade is described above.

The previous binary (`5a8a6a2c…`) cannot be reproduced: it was built in 2020 with a nightly
compiler on a developer machine, and no repository holds its build recipe. Its behaviour is
compared below instead.

## Behaviour: shipped and new libraries compared

`scripts/deps/sr25519-provenance/cross-check-slices.py` runs four archives side by side:
the shipped and the new device slices (retagged by `retag_device_archive.py`, which changes
only the platform field of each object's load command, so their arm64 machine code runs in
an arm64 simulator process on Apple silicon) and the shipped and new simulator slices.
`sr25519_tool.c` calls the C entry points `SNKeyFactory`, `SNSigner` and
`SNSignatureVerifier` call. References that share no code with schnorrkel:
@polkadot/util-crypto 14.0.3 with @scure/sr25519 0.2.0 (`polkadot_reference.cjs`) and a
from-spec Python implementation (`sr25519_reference.py`). Inputs: the root golden catalog
`config/upgrade-matrix/golden-wallets.v1.json` (GW-M1, GW-M4, GW-M5 including the `/0` soft
path, GW-S1, GW-J1) and the Android production-parity vectors
(`build/safe-upgrade/assets/vectors/android-parity`, `05-keypairs.json`, `07-json-keyring.json`).

Result of the run that wrote the committed fixture:

| check | count |
| --- | --- |
| golden public keys equal to both references | 5 |
| derivations per slice equal to golden catalog and both references | 20 |
| deterministic key material byte-identical on all four slices | 3 of 3 |
| soft path: nonce differs on every derivation, scalar and public key do not | 2 of 2 |
| polkadot-js JSON converts to the same stored key on all four slices | 2 |
| Android production-parity derivation vectors reproduced (40 per slice) | 160 |
| `sr25519_sign_checked` signs every key the shipped device slice wrote | 80 |
| signatures verified by each slice, by @scure/sr25519 and by the from-spec reference | 260 each |
| tampered signatures or messages rejected by every verifier | 114 |
| refusals return the documented status and a zeroed buffer | 6 |

To rerun it (it rewrites the fixture; nonces and signatures are random, so the bytes change
but every assertion must pass):

```sh
python3 -I scripts/deps/sr25519-provenance/cross-check-slices.py \
  --checkout <SourcePackages>/checkouts/shared-features-spm \
  --repository <SourcePackages>/checkouts/shared-features-spm \
  --simulator <udid of a booted arm64 iOS simulator> \
  --node-modules-owner <directory with @polkadot/keyring 14.0.3 in node_modules> \
  --golden <root>/config/upgrade-matrix/golden-wallets.v1.json \
  --android-vectors <root>/build/safe-upgrade/assets/vectors/android-parity \
  --out fearlessTests/UpgradeFixtures/Crypto/sr25519-known-answers.v1.json \
  --report build/reports/sr25519-cross-check.json
```

What the checked entry point refuses was already unusable with the shipped binary: on the
shipped device slice `sr25519_sign` returned a signature that verifies under neither key
for a mismatched keypair, and aborted the process (exit 134) for a non-canonical secret or
an invalid public key. The new call returns an error instead (`SNSigner` code 4, 2 and 3).
No stored key that could sign under 4.0.4 is refused.

## Known-answer tests in the app test target

`fearlessTests/Common/Crypto/Sr25519KnownAnswerTests.swift` reads
`fearlessTests/UpgradeFixtures/Crypto/sr25519-known-answers.v1.json`. Its stored keys and
"shipped" signatures were produced by the shipped (4.0.4) device slice, so the keychain rows
the tests create are what 4.0.4 wrote: the 64-byte scalar-and-nonce secret under
`<metaId>-substrateSecretKey` (and the per-chain-account tag), including the random nonce of
a soft junction. The tests:

- sign through the production `SigningWrapper` → `SNSigner` → `sr25519_sign_checked` path,
  as a wallet key and as a chain-account key, for every stored key and four messages, and
  verify each signature with `Sr25519SpecVerifier` (a from-spec Swift verifier in the test
  target that shares no code with the native library) and with `SNSignatureVerifier`;
- verify the shipped device slice's and @scure/sr25519's signatures with both verifiers and
  reject tampered ones;
- import GW-M1, GW-M4, GW-M5 (`//polkadot/0` and `/0`) and GW-S1 through
  `MetaAccountOperationFactory` and compare public key, scalar and (for hard-only paths)
  the full stored secret with what 4.0.4 stored;
- show that a soft junction draws a fresh nonce on every derivation while scalar and public
  key stay fixed (so identity checks must never compare nonces);
- reproduce the 40 Android production-parity derivation vectors;
- import the polkadot-js JSON exports (GW-J1, its soft-path twin and the Android parity
  files), compare the stored key with the 4.0.4 value, sign, export through
  `KeystoreExportWrapper` and re-import to the same key; the unscrypted legacy JSON is
  rejected without writing a key;
- check that the three refused keypairs fail with the expected `SNSigner` error and stay in
  the keychain unchanged.

The tests use no simulator-only API. On a physical iPhone:

```sh
xcodebuild test -workspace fearless.xcworkspace -scheme fearless.tests \
  -configuration Release ENABLE_TESTABILITY=YES \
  -destination 'platform=iOS,id=<device udid>' \
  -only-testing:fearlessTests/Sr25519KnownAnswerTests
```

## What ran where, and what is still open

| what | where | status |
| --- | --- | --- |
| byte-identical rebuild of the 4323032 xcframework | this Mac, 2026-10-11 | done |
| device-slice machine code (shipped and new): derivation, signing, verification, refusals | arm64 simulator process (retagged device archive) | done, counts above |
| `Sr25519KnownAnswerTests` (10 tests) with `SigningWrapperTests` and `KeystoreExportWrapperTests`, Debug, simulator slice | iOS 27.0 and iOS 26.5 simulators, 2026-10-11 | passed, 30 of 30 on each |
| `fearless.tests` built for `generic/platform=iOS`, Debug, unsigned | this Mac, 2026-10-11 | built; the device app links `sr25519_sign_checked` from the `ios-arm64` slice and bundles the fixture |
| `Sr25519KnownAnswerTests` on a physical iPhone, Release build | the only registered phone (iPhone 17 Pro Max, iOS 26.7) was unavailable | **open: release gate** |

The retagged run executes the device slice's own instructions on Apple-silicon cores, which
share the arm64 ISA with iPhone CPUs, but it is not a device run: it does not cover the
device's dynamic loader, code signing or a store-signed build. Before submitting 4.2.0, run
the command above on a physical iPhone against the Release configuration, and keep the
in-place upgrade from App Store 4.0.4 with a real signed transfer (test-matrix, IOS-M1) on
the device checklist.
