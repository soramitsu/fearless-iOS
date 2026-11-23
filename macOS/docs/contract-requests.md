# WalletCore contract requests

Lanes append requests here instead of editing `Packages/WalletCore`. The
coordinator applies or answers each one and marks it done.

Format: `## <date> <lane>: <title>` then what, why, and the proposed Swift.

## 2026-11-22 engine: distinguish wallet creation from mnemonic import

WalletImportSource.mnemonic has identical arguments for a freshly generated phrase and an existing backup. To persist WalletOrigin.created without retaining generated phrases in memory, add WalletImportSource.created(words: [String], options: DerivationOptions), or add an explicit creation method. The engine currently treats both as mnemonic imports.

## 2026-11-22 engine: track and verify the versioned macOS framework

The macOS sr25519 slice is ready for the coordinator to stage. Its 19 existing
iOS files matched their original SHA-256 digests, and the native macOS parity
and signing harness passed. Engine-lane rules assign Git staging and edits to
`scripts/deps/` to the coordinator.

Please stage the new slice, including its relative symlinks, and update
`scripts/deps/verify-native-source.py` for its bundle layout. Four of the
symlinks refer to directories, which the existing `Path.is_file()` inventory
omits. Keep the clean-checkout and byte-hash checks. Compare
`git ls-files Native/Binaries` against the union of `nativeBinaries` and the
new `nativeBinarySymlinks` keys in `config/native-sources.json`. Verify that
the observed set of symlinks and their exact relative target strings equals
that map, retaining the existing checkout-containment checks. A unit test for
a valid versioned framework and for a replaced or retargeted symlink would
cover the change. The current direct verifier output is in
`codex-engine/native-source-verification.log`.

Engine workaround for origin: the service remembers only the public Substrate account identifiers of recently generated phrases until lock. Adding one during the same session records .created. A restored phrase records .mnemonic. An explicit source case would preserve intent across lock/restart.

## 2026-11-22 ui: say whether a new wallet's phrase is backed up

What: let the caller state, when a wallet is added, whether its recovery
phrase is already backed up, and let the UI ask for the reminder again.

Why: onboarding offers "Back Up Later" for a phrase generated on this Mac
and must keep a banner until the backup check passes. An imported phrase is
backed up by definition. `addWallet(name:source:)` cannot tell the two apart
(the engine lane's `.created` request above covers the origin), and there is
no way to set `isBackedUp` to false again.

Proposed Swift (together with `.created`):

```swift
func addWallet(name: String, source: WalletImportSource, isBackedUp: Bool) async throws -> Wallet
```

UI workaround until then: after `addWallet` the UI calls `markBackedUp` for
imports and for created wallets whose check passed. For "Back Up Later" it
keeps the wallet identifier (not a secret) in UserDefaults under
`fearless.ui.pendingBackupWallets` and shows the reminder while the wallet
is in that set or `isBackedUp` is false.

## 2026-11-22 ui: fee and maximum for an incomplete draft

What: document that `prepare` returns `fee` and `maxSendable` whenever the
asset and wallet are known, also when the recipient is empty or invalid and
the amount is zero.

Why: "Max" is usually pressed before the recipient is typed. The UI calls
`prepare` with the draft as it stands (empty recipient, zero amount) and
fills the field from `maxSendable`. If the engine returns nil there, the
button does nothing until the form is complete.

Proposed Swift: a doc comment on `TransferServicing.prepare`, no type change:

```swift
/// `fee` and `maxSendable` are estimated for the wallet's own address when
/// the recipient is missing or invalid; the issues still report the recipient.
```

## 2026-11-22 ui: history in pages

What: page the history.

Why: `activity(of:assets:)` returns the whole history at once. The table
sorts and filters in memory, which is fine for hundreds of rows and not for
an old, busy account.

Proposed Swift:

```swift
func activity(of walletID: WalletID, assets: [AssetID]?, before cursor: String?, limit: Int) async throws -> ActivityPage
// ActivityPage gains: public var nextCursor: String?
```

The UI loads everything in one call until this exists.

## 2026-11-22 ui: icon for assets that are not a network's own token

What: an icon name for tokens such as USDT and USDC.

Why: `Asset.iconName` points into `icons/chains/white/`, which has network
glyphs only. The UI bundles the coloured token icons from
`remote-config/production/icons/tokens/coloured/` and picks one by ticker
symbol, then falls back to the chain glyph, then to a monogram.

Proposed Swift:

```swift
/// File stem in `remote-config/production/icons/tokens/coloured/`, if any.
public var tokenIconName: String?
```

## Coordinator status (2026-11-22)

- engine `.created` / ui backup state: DONE — `WalletImportSource.created`; created wallets start not backed up, every other source backed up.
- engine versioned macOS framework: DONE — slice tracked, `verify-native-source.py` inventories symlinks (`nativeBinarySymlinks`), tests added.
- ui fee and maximum for an incomplete draft: DONE — `prepare` doc guarantee, engine quotes against the sender's own address.
- ui history in pages: DEFERRED — documented as not paged.
- ui token icon: DONE — `Asset.tokenIconName`.
- review M1 outcome unknown: DONE — `TransferProgress.outcomeUnknown(reason:)`.
- review L7 backup details: DONE — `exportMnemonic` returns `MnemonicBackup`; `WalletAccount.derivationPath` never holds the password part.
- review L8 legacy password rules: OPEN — see `build/reports/macos-desktop/codex-engine-fixes/L8-contract-request.md` (known gap in ARCHITECTURE.md).
