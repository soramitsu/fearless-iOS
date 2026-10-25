# Ed25519 signing

`EDSigner` signs as RFC 8032 section 5.1.6 describes. `ed25519_sha2_sign` takes a
64-byte expanded key: the clamped scalar, then the 32-byte prefix that is hashed
with the message to make the per-message nonce. `EDSigner` always passes that
64-byte key.

- `EDKeyFactory -deriveFromSeed:` hashes the seed with SHA-512 once. The
  `EDPrivateKey` it returns still exposes only the 32-byte scalar as `rawData`,
  and keeps the prefix internally. `EDSigner` then produces exactly the RFC 8032
  signature for that seed. This is the wallet path: `Ed25519KeypairFactory`
  derives the key from the stored seed and hands it straight to `EDSigner`.
- An `EDPrivateKey` created from a raw 32-byte scalar has no seed to take the
  prefix from. Its prefix is the first 32 bytes of
  SHA-512(`"IrohaCrypto EDPrivateKey nonce prefix"` || scalar). Its signatures
  are deterministic and valid, but differ from the RFC 8032 signatures of a key
  derived from the seed.
- `EDKeyFactory` rejects seeds and scalar inputs that are not exactly 32 bytes
  before passing them to the C implementation.
- `EDSigner` also accepts private key objects that are not `EDPrivateKey`. They
  must hold exactly 32 bytes and sign like a raw scalar. Any other length
  returns `nil` with the `EDPrivateKey` invalid-raw-data error.

Key derivation is unchanged, so public keys and addresses stay the same. Every
valid signature verifies, so verifiers need no change. The stack copies of the
expanded key are cleared after use, and so is the stored prefix when its key is
released.

## Tests

- `python3 scripts/test-ed25519-blake2-native.py` drives `EDKeyFactory` and
  `EDSigner` from Objective-C. It checks:
  - RFC 8032 section 7.1, including TEST 1024, and every 32nd line of
    `sign.input`, through the wallet path;
  - random seeds against the Python model: public keys, scalars and signatures;
  - raw-scalar keys against the prefix rule above;
  - private keys of the wrong length.
- `Tests/SSFKeyPairTests/ED25519SignerTests.swift` covers the same paths from
  Swift, through both `EDKeyFactory` and `Ed25519KeypairFactory`, plus the
  Substrate `//Alice` public key.
- `python3 scripts/test-ed25519-blake2-native.py --host-asan` builds the native
  code and Objective-C wrappers with AddressSanitizer on macOS. It checks the
  same independent signing results and detects invalid memory reads. This
  check runs in the native compatibility CI job.

On 2026-10-25, the native simulator check and host AddressSanitizer check both
passed 6,037 C operations and 1,790 wrapper operations. The original wrapper
failed the sanitizer check because it passed a 32-byte scalar to a C signer
that reads 64 bytes. The six signing XCTest methods also pass in the combined package suite at
`51984de`; two additional factory-length regressions cover rejected seed/scalar
inputs. The final package qualification records their execution.
