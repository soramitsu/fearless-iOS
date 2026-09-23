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

The disabled passkey generation code authenticates an encrypted envelope,
unwraps a credential-local backup key from a native PRF result and calls the
`PasskeyBackupPlaintextWalletVerifier` protocol. Only synthetic test fixtures
implement that protocol. Before enabling it, the app must serialize the
material above without loss, restore it transactionally into Keychain and the
wallet store, compare every original public identity, prove original-key
signing and export, and pass real iOS↔Android replacement-device recovery with
the original devices unavailable. An owner session and Drive account alone
cannot substitute for these local proofs.
