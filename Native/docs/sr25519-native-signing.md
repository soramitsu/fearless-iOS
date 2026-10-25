# SR25519 native signing boundary

`SNSigner` uses `sr25519_sign_checked` for every wallet signature. The checked
entrypoint validates explicit buffer lengths, parses the secret and public key,
checks that they match, and returns a status without unwinding through C. Its
signature output is cleared on failure. `SNSigner` turns a failure into an
`NSError` through its existing nullable `sign:error:` API. The original
`sr25519_sign` symbol and ABI remain available for existing callers.

The Rust source in `native/sr25519crust` is based on the Apache-2.0-licensed
[Warchant/sr25519-crust commit `2ec5e5309db353b31319cd487c24b63631cf5d9d`](https://github.com/Warchant/sr25519-crust/commit/2ec5e5309db353b31319cd487c24b63631cf5d9d).
The old iOS archive itself names `schnorrkel-0.9.1` in its embedded paths. The
source now pins `schnorrkel = 0.11.5`, `curve25519-dalek = 4.1.3` through the
checksummed `Cargo.lock`, and Rust 1.97.1 in `rust-toolchain.toml`. This removes
the secret-scalar timing issue [RUSTSEC-2024-0344](https://rustsec.org/advisories/RUSTSEC-2024-0344.html).
The runtime graph uses `rand 0.8.8`, removing the old `rand 0.7.3` affected by
[RUSTSEC-2026-0097](https://rustsec.org/advisories/RUSTSEC-2026-0097.html). The
logger-specific advisory conditions have not been shown reachable in the wallet.
The build generator is pinned to `cbindgen = 0.29.4`; its updated graph also
removes the unmaintained `atty` and `ansi_term` build dependencies. A live OSV
query on 23 October 2026 found no matching advisories for all 85 registry
packages in the resulting lockfile. This is a dated scan, not a permanent
guarantee.

The local delta adds the checked signing API and tests, restores the legacy
`sr25519_from_ed25519_bytes` and `sr25519_to_ed25519_bytes` C exports present in
the old wallet binary, and retains framework version symbols. Upstream CMake
and CI files are omitted because this package builds with Cargo and the script
below. The `sr25519lib.h` umbrella header and simulator sidecar archive remain
at their original paths. The upstream `VRFOutput`/`to_output` API is adapted to
`VRFPreOut`/`to_preout`; the new `InvalidKey` error maps to the existing C
`EquationFalse` result without changing enum values. Both rebuilt framework signatures are ad hoc signatures
over their new contents.

With Xcode 27 and the pinned Rust toolchain installed, build and validate from
the repository root:

```sh
cargo test --locked --manifest-path native/sr25519crust/Cargo.toml --lib
python3 scripts/build-sr25519-xcframework.py
python3 scripts/test-sr25519-native.py
```

The build script produces device arm64 and simulator arm64/x86_64 slices from
the checked-in source. It uses deterministic archives and regenerates the
framework metadata and signatures. Repeating it without a source or toolchain
change produced identical SHA-256 hashes for every file in the XCFramework.
The checked-in executable archives have these SHA-256 hashes:

| Slice | SHA-256 |
| --- | --- |
| iOS arm64 `sr25519lib` | `4af3fff90ef0e6fe87bd7528f71dc888ae974dac470f190a87f245f68f2682d4` |
| iOS simulator arm64/x86_64 `sr25519lib` | `7cf16e0951f25f35f74b3b388bb219ad5a35b8ff9a97abd5473a5448396e3cba` |

The simulator `libsr25519crust.a` sidecar is byte-identical to the simulator
framework executable archive. Before this dependency update, the source-built
`b11e20a` executable hashes were
`84479e09b314a608ff8e29156dc3f8cad76a1c4919aaf323e83508cbca1342dc`
(device) and
`c550e3e71d86af24ee01825b63d8aae007739c9802d3573d0841ca4586d887ad`
(simulator). The original prebuilt executable hashes were
`5a8a6a2cf08ffa66f071d4cefab159d51de8a49842bcd44f479b765f901c8886`
(device) and
`463048b6fd787ba0578c4d22de08d41f1ace34a4b638d564f11f38848bf3d3a3`
(simulator).

The native test links device arm64 and both simulator architectures. In an
arm64 iOS simulator it runs the old binary's deterministic keypair, hard
derivation, soft public/scalar, and Ed25519 conversion vectors; signs and
verifies; and exercises the Objective-C `SNSigner` with malformed 64-byte
secret and 32-byte public keys in a separate simulator process. The old and new
libraries also verified one another's signatures in a direct comparison against
`b11e20a` using `--compare-baseline /path/to/previous/sr25519lib.xcframework`.
All 10 Rust unit tests passed. The 13 exported C and framework version symbols
match the baseline on all three architectures; public header declarations are
unchanged (generator comments and whitespace differ). Soft derivation's nonce and signatures are randomized, so their
bytes are not compared. Device execution and x86_64 simulator execution were
not available on this host; their binaries were linked. Full Swift package and
wallet builds were not rerun for this isolated dependency change. The previous
full `Modules-Package` XCTest attempt was blocked by `SSFXCMTests` mock errors
(`XcmCallFactoryProtocolMock` conformance and a missing `chainRegistry` argument). Other legacy native entrypoints still use upstream unchecked parse
behavior; this change specifically closes the wallet signing boundary.
