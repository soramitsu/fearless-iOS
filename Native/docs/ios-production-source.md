# iOS production dependency source

This release compatibility line starts at the wallet's exact dependency revision
`3ad0fe928333c9ac28972e3669ca733c6972f060` (`feature/neon-fix-fearless`).
The separate PR #81 targets `develop`; that line changes wallet storage and other
APIs and is not a drop-in replacement for the existing wallet release.

The wallet's carried fixes now belong in this repository's source:

- One Web3 package identity, using the Soramitsu fork.
- Explicit SSFModels and SSFPolkaswap target dependencies.
- Distinct Objective-C names for the bundled SoraKeystore classes. Keychain tags,
  access controls, storage schemas, and UserDefaults keys stay unchanged.
- Ethereum private-key byte conversion compatible with the pinned Web3 API.
- Static AddressFactory references in the two Polkaswap consumers; no invalid
  instance compatibility extensions.
- Matching SSSE3 compilation and selection guards for scrypt. The public scrypt
  header has no architecture-specific types and needs no NEON include.
- Removal of four redundant `.a` sidecars inside device framework bundles.
  The subsequent SR25519 signing-boundary rebuild is documented in
  [sr25519-native-signing.md](sr25519-native-signing.md). The Ed25519 and
  BLAKE2 binaries were later replaced by pinned C sources
  ([ed25519-blake2-native-provenance.md](ed25519-blake2-native-provenance.md)).
  `sorawallet` retains its original bytes
  ([prebuilt-binary-provenance.md](prebuilt-binary-provenance.md)).
- Public initializers for the three existing pool parameter models.
- The IrohaCrypto umbrella/module-map contract and explicit dynamic sorawallet
  link directive.
- Strict source identity verification replaces wallet post-resolution patch
  accounting once the wallet pins this source. That integration is required;
  publishing this branch alone does not eliminate the wallet patch scripts.

While exercising the actual scrypt implementation, the tests caught a `printf`
of an intermediate derivation buffer. This output is removed. Zero work factors
are rejected before division/allocation. Neither change alters valid derivation
outputs. The tests use public RFC 7914 section 12 vectors and require exact output
with no extra stdout/stderr. They cross-link device arm64, simulator arm64,
simulator x86_64 with SSSE3, and simulator x86_64 without SSSE3.

Run `python3 scripts/test-scrypt-architectures.py` with Xcode installed, and
`swift package dump-package`. Cross-linking is compilation coverage, not real
device execution. Final wallet integration, historical-wallet signing/export,
symbol audits, distribution upgrades, independent review and protected-branch
CI remain required before this source is qualified for release.

Reference: https://www.rfc-editor.org/rfc/rfc7914#section-12
