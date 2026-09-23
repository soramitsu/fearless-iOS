# iOS wallet material required for portable recovery

This is a source inventory for the consolidated iOS candidate. It defines
material that a reviewed cross-platform plaintext format must preserve; it is
not that format and does not enable passkey recovery. The production
`PasskeyBackupPlaintextWalletVerifier` and replacement-device installer do not
exist yet.

| Material | Durable iOS source | Required restore property |
| --- | --- | --- |
| Wallet identity and presentation | `MetaAccountModel` carries the meta ID, name, Substrate and EVM public identities, crypto type, chain-account set, filters, currency, visibility, favorites, backup flag and optional native TON identity. `ManagedMetaAccountModel` and `SelectedWalletSettings` carry selection and order. | Preserve every wallet, its original public identities, selected wallet, order and user-visible settings. The decrypted keys must rederive the original addresses before installation. |
| Substrate root | `KeystoreTagV2` addresses entropy, seed, secret key and derivation path by meta ID. The crypto type and public key live in the wallet model. | Preserve the exact signing key and derivation metadata. Entropy, seed and raw secret-key availability are separate historical cases; a raw-key wallet must not be relabeled as mnemonic-derived. |
| EVM root | `KeystoreTagV2` addresses the EVM secret key, seed and derivation path by meta ID; the model stores public key and address. Some imported EVM keys are independent of the Substrate mnemonic. | Preserve the exact original private/public key and address. Only claim mnemonic export when the restored phrase and path actually reproduce that key. |
| Chain-specific accounts | The same Keychain tags accept an `accountId` suffix. `MetaAccountModel.chainAccounts` identifies per-chain accounts and their public identities. | Include every separately stored chain key, entropy/seed and path; do not infer that a root can reproduce it without proving the public identity. |
| Native TON root | `LegacyTonAccount` stores the validated V4R2 address serialization, public key and contract version. `tonSecretKeyTagForMetaId` stores a 64-byte native private key; `entropyTagForMetaId` may contain the original TON phrase bytes rather than BIP39 entropy. | Preserve the native private key and any recoverable phrase separately, then validate V4R2 address, original-key signing and export. Never run TON phrase bytes through the Substrate/BIP39 entropy codec. |
| Historical address-keyed rows | `SingleToMultiassetMigrationPolicy` moves the original `KeystoreTag` address-keyed entropy, seed, secret key and derivation into V2 meta-ID tags with staged rollback. | Qualify copied historical stores and locked/interrupted migration; do not discard an old key before the new wallet and Keychain transaction are verified. |
| App-owned derived networks | `UniversalWalletMigrationContract`, `BitcoinKeyDerivation` and `UniversalWalletAccountProvisioning` derive additional identities from validated wallet roots. | Record derivation contracts and verify all original public identities and signing/export after restoration; fail if a released derivation changes. |

The existing `OpenBackupAccount` cloud format contains at most one Substrate
and EVM pair represented as a phrase, seed or JSON. The UI selects one export
option; it cannot encode native TON, every chain-specific key, multiple wallets
and all historical secret availability. The legacy Google backup path now
rejects partial export and requires download/decryption readback before marking
a wallet backed up, but that does not make it a portable passkey backup.

`IOSPasskeyWalletMaterialPreflight` is a read-only, count-only safety check for
future portable backup work. It compares raw persisted `CDMetaAccount` row
counts with selection-safe projections, rejects unsupported or quarantined
rows, duplicates, a pending Keychain migration, missing or inaccessible root
and independent chain keys, and public metadata that changes during the read.
It validates an EVM private key against its stored address and a native TON
phrase against the original V4R2 identity. A native TON phrase alone can
recreate the same private key; a private-key-only native TON row fails this
preflight because the released phrase-export UX cannot be preserved. The
persisted iOS model does not represent an EVM-only wallet without a Substrate
or native TON root; such a row remains unsupported and fails closed.

This preflight now checks a local, domain-separated signature against each
stored SR25519/ED25519/ECDSA Substrate root, EVM root and explicitly stored
SR25519/ED25519/ECDSA chain key;
it rejects a readable Keychain item that cannot sign for its original public
identity. It also validates the native TON phrase against its V4R2 identity.
The pinned shared-features source now uses a checked SR25519 C/Rust signing
entrypoint: malformed secret/public keys and mismatched keypairs return a
recoverable signing error, and the preflight fails closed without a process
abort. The rebuilt iOS native library has source, ABI, simulator parity and
architecture-link evidence; physical-device execution and independent review
remain open.
These checks do not serialize all optional entropy, seed and derivation tags,
or prove that the released export UX can reproduce them. Atomic secret capture,
export proof and a transactional installer remain required before allowing any
backup-complete state. Its two wallet-store reads detect ordinary metadata
drift but are not a transaction spanning Core Data and Keychain. The production
passkey feature remains disabled.

The disabled passkey generation code authenticates an encrypted envelope,
unwraps a credential-local backup key from a native PRF result and calls the
`PasskeyBackupPlaintextWalletVerifier` protocol. Only synthetic test fixtures
implement that protocol. Before enabling it, the app must serialize the
material above without loss, restore it transactionally into Keychain and the
wallet store, compare every original public identity, prove original-key
signing and export, and pass real iOS↔Android replacement-device recovery with
the original devices unavailable. An owner session and Drive account alone
cannot substitute for these local proofs.
