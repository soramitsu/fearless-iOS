# Wallet secrets that need the device owner (iOS)

Status (2026-11-24): step 1 is on `release/consolidated-20261110` (`28ebbb15d`, `458e4ddd4`,
`7eeae2317`). Step 2 is implemented behind `ProtectedKeychainPolicy`, which is **off** in this build.
Two independent Codex reviews (gpt-6.2-astra, ultra) of both steps found 15 and then 8 issues; they
are fixed below or listed in section 6. The owner reviews the prompts (section 8) before the flag is turned on. Device checks:
`docs/wallet-secret-user-presence-device-test-plan.md`.

Background: the 2026 MoldyRoost campaign delivers the Coruna and DarkSword iPhone exploit kits
through ads. DarkSword decrypts the keychain on the phone and uploads it. Fearless is on no
published target list, but every wallet secret is a `kSecClassKey` item with
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and no access control, so a keychain dump from an
exploited, unlocked phone holds every recovery phrase and private key. The app PIN does not help:
it gates the UI only, and it is itself stored as plain UTF-8 in the same keychain. Sources and
Codex's audit (finding 1, section 3): `~/dev/fearless/build/reports/ios-moldyroost-20261123/`.

**Goal:** a keychain dump from a hacked, unlocked iPhone yields no usable wallet secret, and no
user loses access to their keys when upgrading from any older version.

**Non-goal:** code running with kernel privileges can still watch a secret while the user signs.
This removes the standing, dumpable copy; it cannot protect a secret during legitimate use.

## 1. Threat model

| Attacker | Today | Wallet moved (step 2) |
| --- | --- | --- |
| Keychain dump on an unlocked, exploited phone | every secret and the PIN | wallet items need Face ID / Touch ID / passcode, so the dump holds no plaintext for them; the PIN is a salted, slow verifier |
| Code injected into the running app | reads any secret at any time | reads a secret only in the seconds after the owner approved a sheet |
| Backups, iCloud, another device | items are `ThisDeviceOnly` | unchanged: `ThisDeviceOnly`, not synchronizable |
| User removes the device passcode | no effect | iOS deletes passcode-bound items: the wallet is restored from the backup that was verified before the move (5) |

## 2. Step 1: no passive secret reads (shipped)

Every path that read a wallet secret without a user action now reads public data, or waits for a
moment the user has just proved who they are. Commit `28ebbb15d`.

- **Bitcoin balance refresh** (`AccountInfoRemoteServiceDefault.fetchBitcoin`) has no secret
  provider. It reads a public account descriptor: the compressed key and chain code of
  `m/84'/coin'/0'` (`BitcoinKeyDerivation.AccountDescriptor`), and derives receive and change
  addresses with BIP32 CKDpub (`secp256k1_ec_pubkey_tweak_add`). Descriptors are stored per wallet
  and network (`BitcoinAccountDescriptorStore`, `UserDefaults` key `bitcoinAccountDescriptors.v1`)
  and used only when the descriptor's `.../0/0` key equals the key the wallet stores and its first
  address equals the address the wallet shows. Without one, refresh reads the stored address and
  marks coverage `.limited`, as it already did for wallets without a phrase.
- **Where descriptors come from:** whenever app-owned accounts are added
  (`addingMissingAppOwnedAccounts`: every create, import and recovery path), when a Bitcoin
  transfer the user confirmed reads the phrase, right after an authorized unlock for every wallet
  that lacks one (`ServiceCoordinator.backfillDescriptorsOfAllWallets`), and during the step 2 move.
- **Bitcoin fee quotes** use the descriptor. A quote reads the phrase only when no descriptor exists
  yet, and that read saves one.
- **App-owned account provisioning** (`ServiceCoordinator`) checks the public account rows first;
  a fully provisioned wallet is never read. When a network is missing, the read waits for the
  authorized-unlock window.
- **Authorized-unlock window** (`WalletAuthorizedUnlock`): opened by a correct PIN, an accepted
  biometric check or a newly saved PIN (`LocalAuthInteractor`, `PinSetupInteractor`); closed after
  60 s or when the app goes to the background. Work that missed it runs at the next unlock
  (`.walletAuthorizedUnlock`).
- **Watched old addresses and the password notice** (`WalletMainContainerInteractor`) run at an
  unlock (and when the main screen opens inside the window) and when the user chooses a wallet;
  the watched check only for wallets that have watched networks. A portfolio refresh or a foreground
  event reads nothing.
- **Account-bound scans:** the Bitcoin scan cache key includes the account's first address, so a
  password wallet that switches accounts never gets the other account's scan.
- **No undercount after the update:** until an account's descriptor exists, refresh keeps the total
  a full scan saved for **that account** (`BitcoinLastKnownAccountStore`) instead of replacing it
  with one address, and offers none of it for sending until a real scan replaces it. Once the
  backfill has looked and found no secret for the account, refresh reads the stored address and
  offers only its confirmed coins that nothing in the mempool spends (from its UTXOs). A saved
  descriptor triggers the portfolio's Bitcoin scan (`.bitcoinAccountDescriptorsSaved`). The window
  is checked again at the read itself, after any queue or network wait. A removed wallet's
  descriptors are never saved again.
- **TON Connect** reads the spending key only to sign an approved `ton_proof`; an address-only
  connection uses the public account.
- **Tests:** `PassiveSecretReadTests` (a `SecretStoreSpy` sees zero reads through background
  refresh, the public checks and the watched check, and the descriptor scan equals the phrase
  scan); `BitcoinAccountDescriptorTests` (BIP84 reference addresses; descriptor addresses equal
  phrase addresses on mainnet and testnet, receive and change, with and without a wallet
  password); `LegacyTonConnectCoordinatorTests.testAddressOnlyConnectReadsNoWalletSecretAndAProofReadsTheKeyOnce`;
  `CovFMiscServiceCoordinatorTests` and `CovHWMCInteractorTests` (nothing read outside the window).

## 3. Step 2: protected items

### 3.1 Format

`ProtectedKeychain` (`Native/Sources/SoraKeystore/Classes/Keychain/ProtectedKeychain.swift`):

| Attribute | Value |
| --- | --- |
| `kSecClass` | `kSecClassGenericPassword` (legacy items are `kSecClassKey`, so the two never collide) |
| `kSecAttrService` | `jp.co.soramitsu.fearless.wallet-secret.v2` (the service carries the format version) |
| `kSecAttrAccount` | the legacy tag, unchanged: `<metaId>[accountId hex]<suffix>` |
| `kSecAttrAccessControl` | `SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .userPresence, …)` |
| `kSecAttrSynchronizable` | `false` |
| `kSecValueData` | the bytes the legacy item held |

Reads pass an `LAContext` through `kSecUseAuthenticationContext`. An evaluated context reads with
no new prompt; an unevaluated one makes the keychain show the sheet with its `localizedReason`.
Existence checks and inventory read attributes only, with `interactionNotAllowed`, and never
prompt. Adding and deleting need no authentication.

`.userPresence` accepts any enrolled biometry **or the device passcode** and survives biometric
changes: a user who loses Face ID gets in with the passcode.

### 3.2 Routing

`Keychain`, the class every call site constructs, consults an optional process-wide
`Keychain.itemRouter` first (`Keychain(routed: false)` never does). `ProtectedWalletSecretRouter`
claims only wallet-secret tags (`WalletSecretTag`: the nine `KeystoreTagV2` suffixes, with an
optional account id of 20+ bytes in hex). The PIN, PIN attempts, biometric enrollment, TON Connect,
WalletConnect and passkey items never move.

- **Read**, wallet `verified`/`committed`/`lost`: if the protected item exists (asked without a
  prompt), read it with the owner's context; if it is missing, read the legacy item. Any other
  wallet: the legacy item, else a protected item left by an earlier move. A cancelled sheet or failed
  authentication never falls back to the legacy item; a missing protected item (passcode removed)
  never blocks a surviving original behind a sheet.
- **Write**: to the protected item only for a tag a verified move covered (`record.tags`). A tag added
  later to a moved wallet stays legacy until a move covers it. Without a usable journal (missing,
  damaged, or a move that stopped half way), the store that already holds the tag keeps it.
- **Delete**: both. **Exists**: either.
- All writes take `WalletSecretWriteLock`, which the move holds while it copies, compares and
  switches authority.

`ProtectedWalletSecretCoordinator.install()` (first thing in `AppDelegate`) installs the router when
the flag is on or when anything was ever moved (a journal record or a protected item). With the flag
off and nothing moved nothing is installed and nothing changes. If the keychain cannot answer at
launch (before the first unlock after a restart) the check runs again when protected data becomes
available, on activation and at every unlock. A veto stops new moves but never strands a moved
wallet; interrupted moves are finished at every unlock whatever the flag says.

### 3.3 One sheet per operation

`WalletSecretAuthorization` holds the context of the operation in progress:

- a protected read off the main thread with no context evaluates `.deviceOwnerAuthentication`
  once (`SystemDeviceOwnerAuthorizer`), and concurrent reads wait for that one sheet;
- a successful in-app biometric check (`BiometryAuth`) keeps its evaluated context for the caller,
  which adopts it only after its own checks accept the result (`LocalAuthInteractor`: trusted
  enrollment), so a Face ID unlock does not ask twice;
- a context lives at most 10 s (`reuseWindow`) and is invalidated when the app goes to the
  background; an evaluation that began before the app went to the background is not adopted;
- background maintenance (descriptor backfill, provisioning, notices, export-option listing) runs
  inside `WalletSecretAuthorization.withoutPrompt`: a protected read there fails instead of showing a
  sheet;
- on the main thread with no context, the read passes an unevaluated context carrying the reason,
  and the keychain shows the sheet itself (this blocks the main thread while the sheet is up).
  Step 1 removed every background reader, so this path is reached only from a user action.

### 3.4 Journal

One generic-password item per wallet (service `jp.co.soramitsu.fearless.wallet-secret-journal`,
account = metaId, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, not synchronizable), JSON,
no secret and no hash of one. Loading lists the accounts first and then reads each record on its own
(iOS does not return the data of every generic password in one query). A record is trusted only if
it is version 1, names the item it was read from and lists only that wallet's tags; anything else is
set aside (`invalidWalletIds`) and the router treats that wallet as journal-less.

```json
{"attempts":1,"reason":null,"state":"verified","tags":["…-entropy","…-substrateDeriv"],
 "updatedAt":"2026-11-24T07:00:00Z","version":1,"walletId":"…"}
```

`staging` → `written` → `verified` (commit point: reads move) → `committed` (originals deleted).
Also `deferred` (with a reason) and `lost`.

### 3.5 Moving one wallet

`ProtectedWalletSecretMigrator`, run by the coordinator on its own queue right after an authorized
unlock (`.walletAuthorizedUnlock`), all wallets in one pass, one sheet for all of them, none when
the unlock used Face ID / Touch ID. Preconditions, all checked without a prompt; any missing one
defers the wallet and writes nothing:

1. the flag is on;
2. the device has a passcode (`canEvaluatePolicy(.deviceOwnerAuthentication)`);
3. every legacy item whose tag starts with the wallet's id is a known wallet tag (attributes-only
   inventory, `Keychain.applicationTags()`);
4. recovery evidence covers **every** item (`ProtectedKeychainRecoveryEvidence`): exactly the items
   one import, restore from a backup, or creation with the phrase confirmed word by word wrote,
   recorded right then (`isBackuped` at creation). Nothing else adds to it: not "skip", not "I will
   risk it", not a partial cloud backup, not an account imported later on its own, not a recovery
   into an existing wallet. `hasBackup` is not evidence. A wallet whose only copy might be this phone
   never moves, because removing the passcode would erase it;
5. at least one item exists, every identity the wallet stores is a positive proof (3.5.1), and the
   identities come out identically from the legacy store and from the wallet's own items alone.

Steps (1–6 under `WalletSecretWriteLock`, after the sheet; the inventory and bytes are read again
first and any change restarts the move as `changedDuringMove`):

1. journal `staging` with the tag list;
2. per tag: delete a stale copy left by an earlier attempt, add the protected copy;
3. journal `written`;
4. per tag: read the copy **with** the owner's context and compare bytes with the original;
5. verify the identities again from the copies (3.5.1);
6. journal `verified`, the commit point;
7. make the Bitcoin descriptors from the copies already in memory, so background work never needs
   another sheet;
8. delete each original, checking right before each delete that its copy still exists;
9. journal `committed`.

Any failure before step 6 deletes this attempt's copies (only where the original exists) and leaves
the originals untouched; the wallet is `deferred` with the reason. A cancelled sheet skips every
wallet until the next launch.

#### 3.5.1 Identities (`ProtectedWalletIdentityCheck`)

A list of facts computed over a keystore, compared between the legacy store, the wallet's items
alone, and the protected copies:

- root phrase and password (compared through a SHA-256 digest in memory, never stored);
- for each universal account the wallet stores (Bitcoin mainnet/testnet, Solana, TON, Taira): the
  secret that derives it, checked against the stored public key;
- a released native TON account's signing key, validated against its stored public key;
- the native TON phrase recreates the stored TON key;
- the Substrate and Ethereum roots and every chain account with its own key: a local,
  domain-separated message signed with the stored key (`SigningWrapper`) and verified against the
  stored public key. A chain account without its own key is not a proof.

Every entry must be a positive proof before anything moves (only the root digest is a value).
Equal lists mean the copies serve every read path the app has; a tag the inventory missed would
show up as a difference.

### 3.6 Interruption, passcode, biometrics

Recovery goes tag by tag and never deletes the only copy of an item:

| Killed at | Journal | Next start (`recoverInterrupted`, never prompts) |
| --- | --- | --- |
| during step 2 | `staging` | delete copies whose original exists, `deferred`; originals were never touched |
| steps 3–5 | `written` | same |
| during step 8 | `verified` | per tag: copy and original → delete the original (copy re-checked first); copy only → done; then `committed` |
| every copy gone, originals all there | `verified` | `deferred` (retry later); nothing to delete |
| some copies gone, others present (copy-only or newer than its original) | `verified` | keep every copy and original, `deferred` (`copyMissing`), never retried over |
| a tag with neither | any | `lost` |
| after step 9 | `committed` | nothing |
| journal unreadable, damaged or lost | — | router: the store that holds each tag |

- **Passcode removed after the move:** iOS deletes the protected items. At the next start the
  wallet is `committed` with its items gone, so it becomes `lost` and the app posts
  `.protectedWalletSecretsLost`; the user restores from the backup precondition 3 required.
  Nothing else is deleted; the wallet row stays.
- **Passcode removed between steps 6 and 8:** the copies vanish while the originals still exist;
  the move returns to `deferred` and the originals stay. Reads reach them without a sheet.
- **Biometrics added, removed or turned off:** `.userPresence` keeps accepting the passcode.
- **App PIN forgotten:** unchanged; the biometric route still opens the app.

Tests (`ProtectedWalletSecretMigrationTests`, in-memory doubles with failure injection): a failure
at every add, read-back, journal save and original delete, then a restart, recovery and a second
attempt, checking after each step that every original reads back through the router; each killed
state built directly and recovered without a prompt; cancel at the sheet and during read-back;
copies that read back differently; each precondition; missing identity material; passcode removed
before and after commit; veto after commit; one sheet for many reads; a biometric unlock context
reused with no sheet.

### 3.7 App PIN

`KeystoreTag.pincode` keeps its tag; its value becomes
`fearless-pin-v1$<iterations>$<salt b64>$<PBKDF2-HMAC-SHA256 b64>` (16-byte random salt, 32-byte
output, 310 000 iterations, `PincodeVerifier`). A value without the prefix is a plain PIN an
earlier release saved and is compared as before. A verifier with damaged fields or a work factor
outside 1 000…2 000 000 is unreadable: like an unreadable PIN it is not counted as a wrong guess.
After a correct plain PIN, `PinSaveCoordinator.upgrade` (the same queue as PIN changes) replaces the
value in place by one `SecItemUpdate` only while it is still exactly that plain PIN, reads it back,
and never undoes a value another write put there. New and changed PINs are saved as verifiers.
Checking a verifier runs off the main queue. Verifiers are written only while the flag is on;
reading understands both forms in every build. Existence checks are unchanged.

A six-digit PIN has 10^6 values: no verifier resists an offline search. The verifier keeps the
PIN itself, often reused elsewhere, out of a dump. Wallet keys never depend on the PIN.

### 3.8 Flag

`ProtectedKeychainPolicy.isEnabled` = (`isCompiledIn` **or**, in Debug builds only, the launch
argument `-FearlessProtectedKeychain YES`) **and** the remote switch `protected_keychain_enabled`
(`RemoteKillSwitch.protectedKeychain`), with the existing veto rules
(`docs/remote-feature-switches.md`): an absent key or failed fetch keeps the last state, an
explicit `false` vetoes and is remembered, an explicit `true` clears a veto. `isCompiledIn` is
`false` in this build. The switch is decoded on its own: a malformed value is ignored instead of
failing the whole remote document.

## 4. Unchanged and adjusted

- Signing, export, cloud backup and emergency export call `Keychain` as before; the router and the
  authorization window add the sheet.
- Emergency export and erasure list each store on its own (`EmergencyWalletMaterialReader.walletTags`):
  a protected store that cannot answer never hides a readable legacy key. The empty-install PIN
  cleanup in `RootPresenterFactory` needs both stores answered for certain (`definitiveWalletTags`).
- Export options are listed without a sheet: a moved item's presence is enough; the export reads
  and verifies it.
- Removing a wallet or logging out forgets its journal entry, recovery evidence and descriptors.
- TON Connect sessions, WalletConnect, passkey and PIN-attempt items.
- macOS has its own vault and is out of scope.

## 5. Upgrade guarantees

- No original is deleted before its copy was read back with the device owner, compared byte for
  byte and the wallet's identities verified from the copies.
- No move without a device passcode and recovery evidence for every item.
- Every interruption leaves at least one complete, readable copy of every item, and every state
  resumes without user input except the one sheet.
- Unknown tags, unverifiable identities, keychain errors and devices without a passcode defer.
- Downgrading after a move is not supported (an older build cannot read protected items). App Store
  users cannot downgrade; TestFlight testers restore from their backup.

## 6. Before the flag goes on (open)

- **Existing wallets have no recovery evidence.** Only wallets imported, restored or confirmed with
  this release onward carry it, so every wallet created by an earlier release stays on the legacy
  store. Moving them needs a "verify your recovery phrase / backup" step whose UX the owner approves
  (section 8). Until then they are exactly as safe as today. Accounts imported on their own never
  carry evidence yet, so a wallet with one stays too.
- Evidence binds to the items an import wrote, not to their bytes; the identity checks at the move
  (3.5.1) are what tie those items to the wallet's public keys.
- Codex follow-up items left for before enabling: binding a protected-only update to per-tag write
  authority in the journal (a reload of `verified` can discard a newer legacy write when the journal
  was damaged), a historical 4.0.x per-chain seed export option that is hidden after a move until
  verified, and launch still querying both keychain services synchronously.
- The watched-address check and the password notice of a **moved password wallet** read its words;
  after the move they run without a sheet, so they are skipped. A public cache of the password and
  no-password account keys (filled during the move) removes this. Opening that wallet's details
  lists nothing for the same reason.
- `.protectedWalletSecretsLost` is posted and logged, but no screen shows it yet.
- A context approved for one operation serves any wallet for its 10 s (Codex 12); binding it to the
  operation's wallet is a refinement.
- Main-thread readers still exist in some presenters. They work (the sheet blocks the main thread)
  and should move to background queues.
- Accounts added to a moved wallet later stay legacy until a move covers them (no partial move yet).

## 7. Physical-device test plan

`docs/wallet-secret-user-presence-device-test-plan.md`.

## 8. UX for the owner to approve

| Moment | Today | With the flag |
| --- | --- | --- |
| Open the app | app PIN or in-app Face ID | unchanged |
| First unlock after the update, wallet backed up, passcode set | — | Face ID unlock: nothing new. PIN unlock: one system sheet, "Protect your wallet keys with your iPhone passcode" |
| Send / sign / connect with a proof | app confirmation if enabled | same, then one system sheet unless an in-app Face ID check just ran |
| Export phrase or JSON, cloud backup | app PIN | app PIN, then one system sheet |
| Balance refresh, foreground, address-only connect | silent | silent |
| Wallet without a verified backup | — | stays as today; nothing shown |
| Passcode removed after the move | — | wallet must be restored from its backup |

Open choice: keep the app PIN in front of the system sheet (two steps for PIN users), or let the
system sheet replace the app's own confirmation for signing when the flag is on. This build keeps
both.
