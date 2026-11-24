# Device test plan: wallet secrets that need the device owner

For `docs/wallet-secret-user-presence.md`, step 2. About 40 minutes. The simulator cannot run it
(no device passcode, so passcode-bound items cannot be created there).

**Use a spare test iPhone with throwaway wallets, never a phone that holds real wallets.** Set a
device passcode and Face ID on it. Record each run in
`build/reports/ios-keychain-user-presence-<date>/device/`: the build's commit, device model, iOS
version, and the console log filtered for `Protected keychain`.

## Builds

- **Store**: the build live on the App Store (also in TestFlight → Previous Builds).
- **Off**: TestFlight internal build of this branch as it is (flag compiled off).
- **On**: Debug build of this branch launched with `-FearlessProtectedKeychain YES` (bundle `.dev`).
- **Base**: Debug build of `release/consolidated-20261110` (bundle `.dev`), for T3's older wallets.

## Wallets (make them in the build each case starts from; write down every address)

- W1 created, phrase confirmed. W2 imported 12-word phrase, standard paths.
- W3 imported phrase with a `///password` path. W4 native TON 24-word wallet. W5 raw seed.

## Cases

**T1. Flag off is today (gate for the next App Store submission).** Store build with W1–W5 and an app PIN. Install **Off**
over it. Unlock with the PIN, then with Face ID; every address and balance as noted; export W1's
phrase (app PIN only); send a small testnet amount. Then install **Store** again from TestFlight →
Previous Builds: unlock with the same PIN, export W2's phrase. Expect no system sheet and no new
screen anywhere, and every wallet working in both directions.

**T2. Upgrade with the flag on.** In **On**: make W1, import W2–W5, set a PIN, relaunch, unlock
with the PIN. Expect one system sheet, then all five wallets move (`a wallet moved` in the log). Relaunch and
unlock with Face ID: no sheet. Export W1 and send from W1: one sheet each. Repeat the unlock on a Touch ID iPhone if one is at hand: PIN unlock takes
under 0.4 s.

**T3. Recovery-phrase check for an older wallet.** Make W2 and W3 in **Base**, then install
**On** over it and unlock. Expect one offer, "Protect this wallet with your
passcode", for W2 only. Turn on screen recording, tap "Enter recovery phrase": the field is covered
and the keyboard stays down; stop recording. Type a wrong phrase: "These words do not match this
wallet. Nothing was changed." Type W2's phrase: one system sheet, then W2 moves. Relaunch: no offer
again, and none ever for W3. On another wallet, tap "Not now": it stays as it is and is never
offered again.

**T4. Interruptions.** In **On**, with a wallet not yet moved: cancel the system sheet (nothing
moves, every operation still works); lock the phone during the sheet. Launch with environment
`FEARLESS_PROTECTED_KEYCHAIN_STOP_AT=written` (app exits), relaunch normally: no sheet at launch,
every wallet exports, the next unlock finishes the move. Same with `=verified`.

**T5. Dump check (the point of step 2).** After T2, run **On** from Xcode, pause it (Debug →
Pause) and type in the lldb console:

```
expr -l swift -- import SoraKeystore
expr -l swift -- print(try! SoraKeystore.ProtectedKeychain().allAccounts())
```

It lists the moved items (for example `<wallet id>-entropy`) without a prompt. Put one of them in
place of `TAG`:

```
expr -l swift -- var r: CFTypeRef?; print(SecItemCopyMatching([kSecClass: kSecClassKey, kSecAttrApplicationTag: "TAG".data(using: .utf8)!] as CFDictionary, &r))
expr -l swift -- import LocalAuthentication
expr -l swift -- let c = LAContext(); c.interactionNotAllowed = true; var d: CFTypeRef?; print(SecItemCopyMatching([kSecClass: kSecClassGenericPassword, kSecAttrService: "jp.co.soramitsu.fearless.wallet-secret.v2", kSecAttrAccount: "TAG", kSecReturnData: true, kSecUseAuthenticationContext: c] as CFDictionary, &d))
```

Expect `-25300` (no legacy item left) and then `-25308` (the protected item exists but needs the
device owner). This is what a keychain dump from a hacked, unlocked phone would hit.

**T6. Passcode removed.** Last, with every backup in hand: turn the device passcode off,
relaunch. Expect moved wallets reported lost (`lost their protected items` in the log) and wallets
never moved intact. Restore each lost wallet from its backup: it works. Turn the passcode back on.

## Exit criteria

Step 2 is merged into the release line with the flag compiled off (owner's call, 2026-11-24);
T1 passes before the next App Store submission from that line. T2–T6 pass before
`ProtectedKeychainPolicy.isCompiledIn` becomes `true` (its own commit, after the owner approves the
prompts in design doc section 8). Any failure blocks, except an extra prompt, which goes to the
owner's UX review.
