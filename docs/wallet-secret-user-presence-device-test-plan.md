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

**T1. Flag off is today (the merge gate).** Store build with W1–W5 and an app PIN. Install **Off**
over it. Unlock with the PIN, then with Face ID; every address and balance as noted; export W1's
phrase (app PIN only); send a small testnet amount. Then install **Store** again from TestFlight →
Previous Builds: unlock with the same PIN, export W2's phrase. Expect no system sheet and no new
screen anywhere, and every wallet working in both directions.

**T2. Upgrade with the flag on.** In **On**: make W1, import W2–W5, set a PIN, relaunch, unlock
with the PIN. Expect one system sheet, then all five wallets move (`a wallet moved` in the log). Relaunch and unlock with Face ID: no sheet. Export W1 and send from
W1: one sheet each. Repeat the unlock on a Touch ID iPhone if one is at hand: PIN unlock takes
under 0.4 s.

**T3. Recovery-phrase check for an older wallet.** Make W2 and W3 in **Base**, then install **On** over it and unlock. Expect one offer, "Protect this wallet with your
passcode", for W2 only. Turn on screen recording, tap "Enter recovery phrase": the field is covered
and the keyboard stays down; stop recording. Type a wrong phrase: "These words do not match this
wallet. Nothing was changed." Type W2's phrase: one system sheet, then W2 moves. Relaunch: no offer
again, and none ever for W3. On another wallet, tap "Not now": it stays as it is and is never
offered again.

**T4. Interruptions.** In **On**, with a wallet not yet moved: cancel the system sheet (nothing
moves, every operation still works); lock the phone during the sheet. Launch with environment
`FEARLESS_PROTECTED_KEYCHAIN_STOP_AT=written` (app exits), relaunch normally: no sheet at launch,
every wallet exports, the next unlock finishes the move. Same with `=verified`.

**T5. Passcode removed.** After T2, with every backup in hand: turn the device passcode off,
relaunch. Expect moved wallets reported lost (`lost their protected items` in the log) and wallets
never moved intact. Restore each lost wallet from its backup: it works. Turn the passcode back on.

**T6. Dump check (the point of step 2).** After T2, in the Xcode debugger: a `kSecClassKey` query
for a moved wallet's tags returns nothing; reading its protected item with an `LAContext` whose
`interactionNotAllowed = true` returns `errSecInteractionNotAllowed`.

## Exit criteria

T1 passes before step 2 merges into the release line. T2–T6 pass before
`ProtectedKeychainPolicy.isCompiledIn` becomes `true` (its own commit, after the owner approves the
prompts in design doc section 8). Any failure blocks, except an extra prompt, which goes to the
owner's UX review.
