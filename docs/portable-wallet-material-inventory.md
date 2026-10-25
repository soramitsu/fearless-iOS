# iOS wallet material required for portable recovery

This is a source inventory for the consolidated iOS candidate. It defines
material that a reviewed cross-platform plaintext format must preserve; it is
not that format and does not enable passkey recovery. The production
`PasskeyBackupPlaintextWalletVerifier` and replacement-device installer do not
exist yet.

| Material | Durable iOS source | Required restore property |
| --- | --- | --- |
| Wallet identity and presentation | `MetaAccountModel` carries the meta ID, name, Substrate and EVM public identities, crypto type, chain-account set, currency, visibility, favorites, backup flag and optional native TON identity. `MetaAccountSelectionModel` carries selection/order and captures raw persisted `assetFilterOptions` and `zeroBalanceAssetsHidden` for this draft; the ordinary wallet model omits those two historical preferences. | Preserve every wallet, its original public identities, selected wallet, order and user-visible settings. The decrypted keys must rederive the original addresses before installation. |
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
persisted iOS model now accepts an EVM-only wallet when its complete public key
derives the stored address; incomplete or mismatched records still fail closed.
Backup preflight requires its original EVM private key and signing proof.

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

`IOSPasskeyWalletMaterialDraftCapture` is an in-memory next step. It reads
every known V2 root and chain-account Keychain
slot: Substrate/EVM/TON secret keys, entropy, Substrate/EVM seeds and derivation
bytes, plus the universal-wallet source marker. It binds chain slots to their
original chain and account IDs, carries every public wallet model with
selection/order and the two historical display preferences, and resets the
copied backup-complete flag because that flag
cannot prove a restored backup. It runs the signing preflight after capturing
the bytes, then re-reads the wallet projections and all
present **and absent** Keychain tags before returning, failing if an ordinary
interleaved mutation is seen. The draft has redacted debug descriptions and
reflection to avoid routine inspection exposing Keychain bytes; it has no
wire serializer or upload caller. EVM-only wallets are captured with their
own secret slot, and independently stored EVM keys on multi-root wallets
remain separate slots.

This remains a capture candidate, not an atomic Core Data/Keychain snapshot:
a concurrent writer can change and restore bytes between reads, and the app
does not yet hold a shared writer lock across both stores. The Android draft
keeps exact Android V3/V2 SCALE secret blobs; these iOS raw Keychain slots are
not an agreed cross-platform plaintext encoding. A reviewed semantic mapping,
canonical serializer, original-key export proof, transactional installer and
real replacement-device tests remain required.

The draft now reuses the released import derivation without writing storage
to reject a captured Substrate mnemonic/path that does not recreate the
persisted public key. It also checks EVM mnemonic/path where the app advertises
that export, and checks generic chain mnemonic paths where their own source
contract applies. A matching root secret alone would not catch these errors.
Native TON phrase proof remains in the existing preflight.

Seed slots are preserved byte-for-byte but remain provenance-dependent:
historical Substrate migration can store a full seed where current import
stores a mini seed, and EVM slots can store a BIP32 seed or final private key.
App-owned Bitcoin, Taira, Solana, TON and Nexus chain identities use separate
derivation contracts, so the generic mnemonic check does not reinterpret
their optional slots. The released seed and JSON export flows, path-only
material, and every exported account's reimport still need direct round-trip
proof. The draft must never establish backup completion until that proof and
the cross-platform installer pass.

The disabled passkey generation code authenticates an encrypted envelope,
unwraps a credential-local backup key from a native PRF result and calls the
`PasskeyBackupPlaintextWalletVerifier` protocol. Only synthetic test fixtures
implement that protocol. Before enabling it, the app must serialize the
material above without loss, restore it transactionally into Keychain and the
wallet store, compare every original public identity, prove original-key
signing and export, and pass real iOS↔Android replacement-device recovery with
the original devices unavailable. An owner session and Drive account alone
cannot substitute for these local proofs.

The read-only iOS receiving Keychain projection now requires any chain
account's recorded entropy, seed and derivation bytes to match an exact
scoped original-source Keychain item in the same journal-bound cohort. A
missing or conflicting item fails before a storage write; a historical
root-derived chain source remains retained separately from its canonical
signing key. The focused projection suite passes 10/10 on the iOS 26.5
simulator, and both touched Swift files pass strict lint and formatting.
This Keychain projection preserves captured iOS source tags only. The receiving
plan now separately decodes Android's V1 source, V2 chain-account and V3 root
SCALE sidecars with bounded canonical lengths, strict optional discriminants,
UTF-8 validation and no trailing bytes. It requires the original private and
public keys, nonce, entropy, seed and derivation path to agree exactly with
their semantic slots, and checks chain/account binding before accepting a
read-only plan. Android sidecars still have no reviewed iOS storage projection
or transactional installer. This source proof does not enable cross-platform
restoration or establish original-key export behavior after installation.

The receiving Core Data projection now binds the semantic cohort to its journal
and produces the app-owned `MetaAccountSelectionModel` records consumed by the
existing exact-replacement mapper. It retains journal-assigned wallet IDs,
cohort order and selected wallet, signed Substrate/EVM/native TON identities,
approved Substrate and app-owned named chain accounts, favorites and native
display preferences. Currency IDs resolve only against an explicit local
catalog. The backup-complete flag remains false and the projection returns the
existing install blockers; a representable public after-image is not an install
authorization or proof that the corresponding Keychain bytes were staged.

Watch custody has no discriminator in the released iOS wallet model, so any
watch slot rejects the whole projection. Android-only display values,
uninitialized wallets, nonempty per-chain names, unsupported chain identities,
explicit nonfavorite records and root combinations the mapper cannot round-trip
also reject before returning any records. The native source bytes remain in the
semantic/key projection, not in Core Data. A complete installer still needs the
writer boundary, durable journal, foreign-source/display storage, final signing
and export readback, and real cross-platform replacement-device qualification.

The projection and existing mapper regression suites pass 25/25 tests in the
iOS 18.1 arm64 Release simulator, with no skips or failures. The new tests write
and refetch real Core Data records for mixed Substrate/EVM roots, standalone
EVM, native TON, TON/EVM, historical SS58 Substrate and named chain accounts,
and reject altered journal/signer data or unrepresentable complete cohorts.
