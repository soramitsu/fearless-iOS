# Prebuilt binary provenance

Three of the wallet's native binaries were already accounted for:

- `sr25519lib` is rebuilt from pinned Rust source; see
  [sr25519-native-signing.md](sr25519-native-signing.md).
- `libed25519` and `blake2lib` are now built from pinned C sources; see
  [ed25519-blake2-native-provenance.md](ed25519-blake2-native-provenance.md).

Two prebuilt binaries remain. This record states what each is, where it came
from, and what reproducing it would take. Neither has been rebuilt yet.

## sorawallet.xcframework

`Binaries/sorawallet.xcframework` is a dynamic Kotlin/Native framework, bundle
identifier `jp.co.soramitsu.xnetworking.sorawallet.sorawallet`. It provides the
SORA history, fiat and configuration clients that `SSFPolkaswap` imports, and
`IrohaCrypto` links it. It was added in `67eebf2` (2024-02-05) and has not
changed since.

| Slice | Executable SHA-256 | Notes |
| --- | --- | --- |
| iOS arm64 | `acaf61f4a79fd5e33002a24298f36c981249752d411a60d01182f197d671a214` | Minimum iOS 12.0, SDK 16.1, UUID `35E44070-F4E3-3FEB-9268-AB810C1A56A4`, matching the bundled dSYM |
| iOS simulator arm64/x86_64 | `8edddc4081fd9182ff37acc8c6386e4290768f7d93e238ffd34080b0829a23f1` | |

The bundled dSYMs record the build:

- **Compiler.** The DWARF producer is `kotlin-compiler: 1.9.10`, built with
  Gradle 8.2.
- **Sources.** They came from a developer's local checkout of
  [soramitsu/x-networking](https://github.com/soramitsu/x-networking), modules
  `lib/basic` and `lib/sorawallet`.
- **Libraries.** The dSYMs also reference SQLDelight 1.x with SQLiter, Stately,
  multiplatform-settings, Ktor client and kotlinx.serialization, all built by
  their upstream CI.

The public x-networking history starts on 2024-05-29. v0.2.12 (`8040fe2`,
2024-05-31) imports the earlier codebase as a single commit. The exact revision
this February 2024 framework was built from is not published.

To reproduce it:

1. Pin a source revision. Compare the framework's exported Objective-C header
   with `lib/sorawallet` and `lib/basic` at v0.2.12, or obtain the original
   revision from its author.
2. Build with Kotlin 1.9.10 and Gradle 8.2, with dependency versions locked as
   at that revision.
3. Compare code sections and exported symbols rather than whole files.
   Kotlin/Native embeds absolute source paths in its debug info, and dynamic
   frameworks carry an ad hoc or developer signature.

## yttrium (reown)

yttrium is not in this package. The wallet gets it through
`reown-swift` 1.8.0, which depends on `https://github.com/reown-com/yttrium`
exactly at 0.9.75 (`3c8222684e5164af98027494226071d720e6e1d1`). That revision's
`Package.swift` declares two checksum-pinned binary targets. SwiftPM refuses a
download whose SHA-256 differs from the declared checksum.

| Binary target | Release asset | Checksum |
| --- | --- | --- |
| `YttriumXCFramework` | `releases/download/0.9.75/libyttrium.xcframework.zip` | `7e1f54b3379cc0d53a165636868a8d823d8a6efdb37c772ca33bc2a7b6c9c978` |
| `YttriumUtilsXCFramework` | `releases/download/0.9.74/libyttrium-utils.xcframework.zip` | `9a54019eb2899f9d6e98afa0804e21e2a0dc1b444f7196621feb79d8081c4732` |

Both are static Rust libraries with UniFFI bindings.

- **CI build.** They were built by yttrium's `release-swift.yml` and
  `release-swift-utils.yml` GitHub Actions workflows on `macos-latest-xlarge`.
  The workflows run `rustup update stable`, `make setup-thirdparty` and
  `make build-xcframework`, then compute the checksum with
  `swift package compute-checksum` and open the release pull request.
- **Release commits.** That pull request commit, `3c82226`, sits on `5281e48`
  for 0.9.75. For 0.9.74, `2cf70a0` sits on `8347d50`.
- **Rust toolchain.** The workflows install whatever stable Rust is current.
  The libraries' embedded panic paths name
  `/rustc/1159e78c4747b02ef996e55082b704c09b970588`, which is Rust 1.90.0
  (2025-09-14).
- **Build environment.** The embedded crate paths
  (`/Users/runner/.cargo/registry/...`) show a GitHub-hosted runner. Crate
  versions are pinned by the repository's `Cargo.lock`. The objects target
  iOS 13.0.

The libraries as extracted by SwiftPM have these hashes:

| Library | SHA-256 |
| --- | --- |
| `libyttrium.a`, iOS arm64 | `97ecd398caa47c269149669a313048d5bd69c3ea64b1fa7cd64324cc738c2ccb` |
| `libyttrium.a`, iOS simulator | `4f31b77c9484dbd3d03c90a56217caffde53370034cd0baccbb024892cbad877` |
| `libyttrium-utils.a`, iOS arm64 | `b4cc2972ce64a3624db8e78cd5efbb76af2bb711f122bc75fe2ede0a5185076e` |
| `libyttrium-utils.a`, iOS simulator | `6e133e4c7db0e4535c1d705d9a6226d30b591c6f55d0e1c22218f694920304a8` |

To reproduce them:

1. Check out the commits above with submodules.
2. Install Rust 1.90.0 with the iOS device and simulator targets, and the Xcode
   version named in the release workflow's log.
3. Run `make build-xcframework` (or `make build-utils-xcframework`). Build
   under `/Users/runner/work/yttrium/yttrium`, or remap that path with
   `--remap-path-prefix`.
4. Compare the static libraries. The zip checksums cannot match because zip
   records file times.
