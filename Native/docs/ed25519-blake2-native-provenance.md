# Ed25519 and BLAKE2 native provenance

`libed25519` and `blake2lib` used to be prebuilt binary targets
(`Binaries/libed25519.xcframework`, `Binaries/blake2lib.xcframework`). They are
now C targets compiled from pinned public sources. `IrohaCrypto` imports the
same headers and links the same symbols. This record covers where the old
binaries came from, why they were not rebuilt byte-for-byte, and how the
replacement was checked.

## What the old binaries contained

Each framework held a static archive. Every object in it traces to an archive
that Soramitsu committed to [soramitsu/ios-crypto](https://github.com/soramitsu/ios-crypto),
the source of the former IrohaCrypto CocoaPod:

| Objects | Committed archive | Built from | Toolchain recorded in the objects |
| --- | --- | --- | --- |
| `ed25519.c.o`, `fe_*.c.o`, `ge_*.c.o`, `sc_*.c.o`, `sha3*.c.o`, `urandom.c.o`, `ed25519_dummy.c.o` (42) | `IrohaCryptoImp/libed25519.a`, ios-crypto `95be0ac` (2018-10-15) | [hyperledger/iroha-ed25519](https://github.com/hyperledger/iroha-ed25519) tag `1.3.1` (`12de1cb`), with ref10, sha3_brainhub and dev_urandom; static Release build by ios-crypto's `lib-build.sh` with leetal/ios-cmake `096778e` | Apple LLVM 10.0.0 (clang-1000.11.45.2, Xcode 10.0), `-O3`, arm64-apple-ios8.0, embedded bitcode |
| `add_scalar.o`, `fe.o`, `ge.o`, `key_exchange.o`, `keypair.o`, `sc.o`, `seed.o`, `sha512.o`, `sign.o`, `verify.o` | `ed25519Imp/libed25519_sha2.a`, ios-crypto `b178672` (2020-07-26) | [ERussel/ed25519](https://github.com/ERussel/ed25519) `c4b3687`, a fork of [orlp/ed25519](https://github.com/orlp/ed25519) `7fa6712`; CMake 3.15.4 Xcode generator, Debug, iOS 9.0 | Apple clang 11.0.3 (clang-1103.0.32.62, Xcode 11.5), `-O0 -g`, arm64-apple-ios9.0 with bitcode; x86_64 for the simulator |
| `blake2b.o`, `blake2s.o` | `blake2Imp/libblake2.a`, ios-crypto `d593430` (2020-07-02) | [ERussel/blake2_mjosref](https://github.com/ERussel/blake2_mjosref) `39589d9`, a fork of [mjosaarinen/blake2_mjosref](https://github.com/mjosaarinen/blake2_mjosref) `3491779` (the RFC 7693 reference code) | Apple clang 11.0.3, `-O0 -g`, arm64-apple-ios9.0 with bitcode |

- **ed25519_dummy.c.o.** It carries the CMake configuration string
  `VERSION-1.3.0-ref10-sha3_brainhub-dev_urandom-STATIC-Release`.
- **ERussel/ed25519 fork.** Its commit `8cce03c` also contains the build
  directory. That includes the CMake cache and `build/Debug-iphoneos` and
  `build/Debug-iphonesimulator` archives, whose 20 members are byte-identical to
  ios-crypto's `libed25519_sha2.a`.
- **Fork changes.**
  - ERussel/ed25519 renames the public functions to `ed25519_sha2_*` and SHA-512
    to `sha2_512`, adds `ed25519_sha2_derive_keypair`, and drops the Windows seed
    code. `ed25519_add_scalar` was not renamed, although the header declares
    `ed25519_sha2_add_scalar`.
  - ERussel/blake2_mjosref only moves the headers to `include/blake2/`.
- **Embedded source paths and compilers.** The bitcode embedded in each object
  names its source file in these trees. It also names the compiler, with debug
  line tables for the `-O0` objects.

The frameworks were assembled with Xcode 15.0 and committed on 2023-10-31. That relink stripped
DWARF and re-encoded relocations and unwind tables. The code is unchanged:
`python3 scripts/trace-ed25519-blake2-binaries.py` fetches the published
archives and checks every object in every slice. It compares section bytes,
resolved relocations, symbols, unwind entries and platform.

The simulator arm64 objects are the device objects with their platform load
command rewritten to iOS Simulator (minimum 12.0, SDK 13.0). The x86_64
simulator slices are incomplete:

- `libed25519` has only the `ed25519_sha2` objects.
- `blake2lib` has only its version symbols.

That is why generic simulator builds failed at the x86_64 link.

## Why the old frameworks were not rebuilt byte-for-byte

- **Signatures.** The device slices carry code signatures from a private Apple
  development certificate.
- **Wrappers and relink.** The framework wrappers and the relinked objects come
  from Xcode 15.0. The objects themselves were compiled by Xcode 10.0 and 11.5.
  Those Xcode releases are only distributed to signed-in Apple developer
  accounts, and they do not run on current macOS.
- **No open-source substitute.** The open-source Swift 4.2 toolchain from
  swift.org, the closest public match to Xcode 10.0, ships no C compiler
  driver.
- **SDK-bound debug info.** The `-O0` objects embed debug metadata that refers
  to the iOS 13.5 SDK headers.

The binaries are therefore replaced by source targets instead.

## Replacement

| Path | Content |
| --- | --- |
| `Sources/libed25519/iroha-ed25519` | The files of iroha-ed25519 `12de1cb` that the shipped configuration compiles, unmodified |
| `Sources/libed25519/iroha-ed25519-build` | The two files CMake generated for that build: `ed25519_export.h`, as installed in ios-crypto, and `ed25519_dummy.c` |
| `Sources/libed25519/ed25519-sha2` | ERussel/ed25519 `c4b3687` sources and headers, unmodified (an altered version of orlp/ed25519, see above) |
| `Sources/blake2lib/blake2_mjosref` | ERussel/blake2_mjosref `39589d9` sources and headers, unmodified |
| `Sources/*/include` | The old frameworks' public headers, byte-identical |
| `Sources/*/*_vers.c` | The old frameworks' version symbols |

- **Manifest.** `native/ed25519-blake2-sources.json` records every file:
  repository, revision and SHA-256 for upstream files, and the origin of the
  rest.
- **Verify.** `python3 scripts/vendor-ed25519-blake2-sources.py` fetches the
  pinned revisions and checks every vendored byte. It also checks that each
  target folder holds nothing else, and that the public headers equal the old
  frameworks' headers at `eebd107`.
- **Reproduce.** `--write` recreates the upstream files from the pinned
  revisions.

The new targets export the same 117 symbols as the old device archives. The
quirks above are kept, including `ed25519_add_scalar` and `libed25519_version`.

Licenses travel with the sources:

- iroha-ed25519: Apache-2.0, with the ref10 and SHA3IUF parts in the public
  domain.
- ERussel/ed25519: the orlp/ed25519 zlib license.
- blake2_mjosref: CC0.

SwiftPM builds C targets at `-O0` (Debug) and `-Os` (Release), not at the
original `-O3`/`-O0`. Both levels are tested below.

Apps now link this code directly. They no longer embed `libed25519.framework`
or `blake2lib.framework` stub bundles, so release tooling must stop expecting
those bundles or dSYMs for them. Generic simulator builds also link x86_64 now.

The old static archives had these SHA-256 hashes at `eebd107`:

| Archive | SHA-256 |
| --- | --- |
| iOS arm64 `libed25519` | `8977bb6e6c6ba5b6b50f8791ad32e591ca0318d2e55dcd0cb70d43fd272d6220` |
| iOS simulator `libed25519` | `97142c54f34a4e3e3df81f117f20cd96c60428c5be057e33d22de83c72de50f9` |
| iOS arm64 `blake2lib` | `a9756c529c8e36dc252ddbc62c7be5d2abe269987b9105899711545111c98b09` |
| iOS simulator `blake2lib` | `e5f22e938983271f86eb79dd6deebf8d2b7cdf134abd1ac16badf28392461d85` |

## Verification

`python3 scripts/test-ed25519-blake2-native.py` runs one operation list through
a C harness and an Objective-C harness. The Objective-C harness drives the
`IrohaCrypto` wrappers: `EDKeyFactory`, `EDSigner`, `EDSignatureVerifier`,
`IRIrohaKeyFactory`, `IRIrohaSigner`, `NSData+Blake2`, `NSData+SHA3`, and
BIP39 seed derivation. Each harness is built five ways:

- against the old archives, read from git history and checked against the
  hashes above;
- from the sources at `-O0` and `-Os` for the arm64 simulator;
- at `-Os` for the x86_64 simulator;
- for arm64 devices (link only).

`--xcode-products` adds the `libed25519.o` and `blake2lib.o` that Xcode builds
for the package.

The operation list combines four kinds of checks:

- **Public vectors.**
  - Ed25519 (SHA-512): RFC 8032 section 7.1 and every 32nd line of
    `sign.input`.
  - Iroha's SHA3-512 Ed25519: every 32nd line of iroha-ed25519's
    `sign.input.with.sha3.txt`.
  - SHA3-256/512 and SHA-512: iroha-ed25519's hash vectors.
  - BLAKE2b/BLAKE2s: RFC 7693 appendices A and B, and the complete official
    BLAKE2 KAT, compared by digest.
  - The Substrate `//Alice` Ed25519 key, derived from the development phrase
    through the wrapper path the wallet uses.
- **Random cases checked against a separate Python model.** The model uses
  RFC 8032 arithmetic, an RFC 7748 ladder for key exchange, and hashlib.
- **Malformed inputs that only the old binaries can answer.** These include
  corrupted signatures, messages and keys, non-canonical S, small-order and
  invalid points, and out-of-range BLAKE2 parameters.
- **Old/new agreement.** Every build must print exactly what the old archives
  print.

Results on 2026-10-23 (Xcode 27.0):

| Run | Native operations | Wrapper operations | Of which checked against independent results |
| --- | --- | --- | --- |
| default | 6,037 | 1,627 | 4,690 + 1,470 |
| `--seed 1 --scale 20` | 84,298 | 27,847 | 69,841 + 25,410 |

- **Outputs.** All builds produced identical output, including the Xcode
  Release objects.
- **Simulators.** arm64 ran on iOS 27.0. x86_64 ran on iOS 18.4, because the
  iOS 26 and 27 simulator runtimes are arm64-only.
- **Device.** Device arm64 builds were linked, not run.
- **Xcode.** Xcode builds of the `IrohaCrypto` scheme succeeded with the new
  targets: Release for generic iOS device and generic iOS Simulator (arm64 and
  x86_64), and Debug for the simulator.

Wallets keep their addresses and their ability to verify signatures:

- Key derivation and the deterministic signing functions match the old
  binaries byte for byte.
- `IRIrohaSigner` signatures match too.
- The 2026-10-23 run compared `EDSigner` signatures by verification only.

### EDSigner follow-up (2026-10-25)

`EDSigner` now supplies the full 64-byte expanded key that the unchanged C
signer requires. The Objective-C wrapper tests compare seed-derived signatures
with RFC 8032 vectors and an independent Python model, and test deterministic
signing from legacy 32-byte scalars. Public keys and serialized scalars remain
unchanged. See [ed25519-signing.md](ed25519-signing.md).

The default native check passed 6,037 C operations and 1,790 wrapper operations,
including 4,690 and 1,633 independently specified results respectively. These
ran against the old archives and new sources at `-O0` and `-Os` on arm64 iOS
27.0, plus `-Os` on x86_64 iOS 18.4. All four device arm64 harnesses linked.
The Xcode Release-object option was not rerun for this wrapper repair.

`python3 scripts/test-ed25519-blake2-native.py --host-asan` also passed those
operations with AddressSanitizer on macOS. Before the wrapper repair, the same
mode reproduced a dynamic stack buffer overflow in `EDSigner` through
`ed25519_sha2_sign` and `sha2_512_update`.
