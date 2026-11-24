# Device test plan: wallet secrets that need the device owner

For `docs/wallet-secret-user-presence.md`, step 2. Run this before `ProtectedKeychainPolicy.isCompiledIn`
becomes `true`. The simulator cannot run it: it has no device passcode, so passcode-bound items
cannot be created there and every move defers (`ProtectedKeychainHostedTests`).

Record each run in `build/reports/ios-keychain-user-presence-<date>/device/` with the build's commit,
the device model and iOS version, a screen recording, and the console log filtered for
`Protected keychain`.

## Builds

| Build | How the flag is on | Bundle | Use |
| --- | --- | --- | --- |
| Debug from this branch | launch argument `-FearlessProtectedKeychain YES` (Xcode scheme, or `xcrun devicectl device process launch … -- -FearlessProtectedKeychain YES`) | `jp.co.soramitsu.fearlesswallet.dev` | D1–D9 |
| Debug from the base (`87739d9f6`) | — | `.dev` | the "before" app for D1 |
| Release with `isCompiledIn = true`, TestFlight **internal** group only | compiled in | production | D10 (upgrade from the App Store build); never promoted |

Debug-only stop switch: environment `FEARLESS_PROTECTED_KEYCHAIN_STOP_AT=staging|written|verified|committed`
ends the process right after that journal state is saved (D5).

## Devices

- A: Face ID iPhone, current iOS 26.x, passcode set.
- B: Touch ID iPhone on iOS 16.7.x or 18.x (oldest supported family in use), passcode set. Also
  the PIN-timing check (D9).
- C: any iPhone with **no** passcode (D6).
- An iPad with Touch ID or Face ID for one pass of D2.

## Wallet fixtures (create with the "before" build)

1. Created wallet, phrase confirmed (backed up).
2. Created wallet, phrase **not** confirmed (no backup).
3. Imported 12-word phrase with a `///password` Substrate path.
4. Imported raw Substrate seed (raw-seed bridge).
5. Imported JSON (Substrate) plus an Ethereum key.
6. A released native TON wallet (24 words).
7. A wallet with a chain account imported for one network.
8. A wallet holding testnet BTC on a change address (to see full balance coverage).

## Cases

**D1. Upgrade, PIN unlock.** Install the "before" Debug build, add fixtures 1–8, set an app PIN,
note every address and balance. Install this branch's Debug build over it with the flag on.
Unlock with the PIN.
- Expect one system sheet ("Protect your wallet keys with your iPhone passcode") and no second.
- Expect fixtures 1, 3–8 `committed`, fixture 2 not moved (`notBackedUp`). Check from Xcode's
  console: `Protected keychain: a wallet moved` per wallet.
- Every address and balance equals the notes; Bitcoin balance of fixture 8 is complete.
- Export each moved wallet's phrase / JSON: one system sheet each, the material equals the
  original. Send a small testnet amount from fixtures 1 and 8 and sign a TON proof from fixture 6:
  one sheet each.
- Kill and relaunch: nothing moves again, no sheet at unlock.

**D2. Upgrade, Face ID / Touch ID unlock.** As D1, unlocking with biometrics. Expect **no** extra
sheet: the unlock's context is reused (`BiometryAuth` hand-over). If iOS shows a second sheet,
note it: the evaluated biometric context did not satisfy `.userPresence` on that iOS version
(still correct, one more prompt).

**D3. Cancel.** Cancel the migration sheet: nothing moves, no sheet again until relaunch, every
operation still works from the legacy items. Relaunch and accept: wallets move. Then cancel the
sheet during a send and during an export: the operation stops with an error and nothing falls back
to an unprotected read (console shows no legacy read for that tag).

**D4. Background and interruptions.** During the migration sheet and during a send sheet:
press the side button (lock), take a call, switch apps. On return: either the operation finished or
it failed cleanly; every wallet still exports.

**D5. Kill at each step.** For each of `staging`, `written`, `verified`, `committed`: launch with
`FEARLESS_PROTECTED_KEYCHAIN_STOP_AT=<state>`, unlock with the PIN, accept the sheet; the app
exits. Relaunch without the variable. Expect: no sheet at launch (recovery never prompts), every
wallet exports and signs, the journal ends `deferred` (staging, written) or `committed`
(verified, committed), and the next unlock completes deferred moves.

**D6. No passcode.** Device C: the flag on, unlock. Expect no sheet, no move (`passcodeNotSet`),
everything works as before. Then set a passcode, relaunch, unlock: wallets move.

**D7. Passcode removed after the move.** Device A after D1, with every fixture's backup in hand:
Settings → Face ID & Passcode → Turn Passcode Off. Relaunch Fearless.
- Expect the moved wallets marked lost (console `lost their protected items`,
  `.protectedWalletSecretsLost`), fixture 2 (never moved) intact.
- Restore each lost wallet from its backup; it works. (This is why precondition 3 exists.)

**D8. Biometric changes.** After D1: add a second face / finger, then remove all biometrics, then
re-enroll. After each change: unlock, send, export. Expect the passcode always works and nothing
is lost (`.userPresence` is not bound to the enrolled set).

**D9. App PIN.** After D1 (flag on), the PIN item holds `fearless-pin-v1$…` (read it with the
Xcode debugger: `Keychain().fetchKey(for: "pincode")`). Wrong PIN ×6: the lockout counts as before.
Change the PIN: the new value is a verifier. Unlock only with biometrics on a fresh install of the
"before" build: the plain PIN stays until the PIN is typed once. Measure unlock latency on device B
(PBKDF2 310 000 rounds): under 400 ms, otherwise lower `PincodeVerifier.iterations` and re-measure.

**D10. App Store upgrade.** On device A with the App Store build and fixtures 1, 3, 6 (production
wallets with small balances), install the TestFlight internal build (`isCompiledIn = true`), unlock
with the PIN, accept the sheet. Repeat D1's checks. Then veto: set `protected_keychain_enabled: false`
in the development remote config the build reads, relaunch: moved wallets still work, new wallets
do not move. Clear the veto.

**D11. Dump check.** On the device after D1, from the Xcode debugger (Debug build) run a query for
`kSecClassKey` items with the moved wallets' tags: none. Query the protected items with an
`LAContext` whose `interactionNotAllowed = true`: `errSecInteractionNotAllowed` (the item exists
but needs the owner). This is the property DarkSword's dump would hit.

## Exit criteria

D1–D9 pass on devices A and B, D6 on C, D10 on A. Every failure is a blocking bug unless it is
only an extra prompt (record those for the owner's UX review). Then the owner approves the prompts
(design doc, section 8) and `isCompiledIn` changes in its own commit.
