# TestFlight 4.2.0 Upgrade Recovery Gate

Build `4.2.0 (2026.8.10)` failed upgrade qualification after the affected
phone deterministically reported `SUBSTRATE_COMPATIBILITY_MISSING`. Build
`4.2.0 (2026.8.13)` corrected that migration but exposed an iOS 26 tab-bar
replacement regression on the affected phone. Build `4.2.0 (2026.8.14)` was
uploaded to App Store Connect with warnings and its build number is consumed;
it must not be reused. Build `4.2.0 (2026.8.15)` restored the legacy tab bar's
visibility but did not contain the completed navigation redesign. Build
`4.2.0 (2026.8.17)` added the redesign but omitted Bitcoin from the production
chain catalog and wallet lifecycle. Corrected successor build
`4.2.0 (2026.8.18)` added Bitcoin but default-disabled Polkaswap mutations and
could permanently install a startup placeholder before SORA services were
ready. Build `4.2.0 (2026.8.19)` restored Polkaswap but left its modal-era swap
action under the redesigned translucent tab bar on iPhone 17 Pro Max.
Build `4.2.0 (2026.8.20)` corrected that action, but Bitcoin remained absent
for existing wallets whose BIP84 account had not been provisioned. Build
`4.2.0 (2026.8.21)` made Bitcoin visible and added safe recovery, but did not
publish Taira Testnet into the production chain catalog. Build
`4.2.0 (2026.8.22)` added Taira, but both app-owned network rows still waited
for the remote chains request to finish; a stalled or offline request could
hide Bitcoin and Taira. Build `4.2.0 (2026.8.23)` persisted both rows locally,
but retained the old Bitcoin branding/service behavior and treated every
Keychain read error like a missing mnemonic. Corrected successor build
`4.2.0 (2026.8.24)` uses the official Bitcoin mark, the public Mempool.space
Esplora service, and authentic stored BIP39 root entropy only for automatic
standard BIP84 provisioning. Missing entropy remains an explicit mnemonic-only
recovery path; protected-data and other Keychain failures fail closed instead
of manufacturing a different Bitcoin identity. Corrected successor build
`4.2.0 (2026.8.25)` binds Taira reads to `https://taira.sora.org` and canonical
XOR `xor#universal` (`6TEAJqbb8oEPmLncoNiMRbLEK6tw`) using the reviewed Iroha
`optimizations` source contract at
`d8544f1d4d3a73c4a17873250a483208c9aafc16`. It validates unconstrained
`NumericSpec` with wallet-adapter precision `28` and keeps
`xor#sora.universal` (`61CtjvNd9T3THAR65GsMVHr82Bjc`, scale `9`) distinct.
The successor retains ancestry from
distributed source commit
`2e45e55dc03ad904598e730cfb5994fb5c1072dc`, the exact public App Store
Substrate v8/v9 compatibility models and lossless v10 migration, the redesign,
native BIP84 Bitcoin catalog/account/balance/receive/send integration, and
read-only Taira Testnet catalog/account/balance/receive integration with Iroha
Send kept unavailable. Bitcoin and Taira omit Switch Node, while their
chain-account screens hide the otherwise empty ellipsis. The successor must remain blocked from the public beta
group until the affected phone passes this gate using the Apple-delivered
restricted TestFlight build.

## Data boundary

- Do not uninstall, offload, downgrade, clear app data, reset Keychain, or
  repeatedly press Retry.
- Do not copy the User/Substrate databases, app container, wallet identifiers,
  Keychain values, or raw device logs without separate explicit approval.
- Capture only installed bundle/version metadata and process-filtered,
  privacy-sanitized Fearless startup messages.
- Keep the original `4.2.0 (2026.7.28)` app container intact until the safe log
  capture is complete and the internal TestFlight update is ready.

The host-side `scripts/filter-startup-syslog.py` filter accepts NDJSON from a
Fearless-process-only syslog stream. It writes timestamps, severity, safe
subsystem/category labels, and redacted startup messages; it never writes the
unfiltered input.

For distributed build `2026.7.28`, known source-derived error descriptions are
reduced to stable `legacy_incident_code`, `legacy_resolution`, and—only for a
low-space failure—the required free-byte count. Dynamic model/entity names,
paths, current free-space values, and unmatched error text are never retained.

## One `.28` diagnostic capture

Use `scripts/capture-testflight-startup.py`; do not pipe a broad device log to a
file. The supervisor requires the reviewed `pymobiledevice3` version `10.7.2`,
allows exactly one connected USB device, confirms the installed bundle/version,
and, after observing the new Fearless PID, requests only that PID from the
device's log service. The request uses `PROCESS_ONLY` and `NO_SENSITIVE` and
does not request historical logs, broad device logs, or call stacks. Its raw
stdout connects directly to the sanitizer through an OS pipe. Device identifiers
and process IDs remain in memory and are never published.

Choose a new absolute output directory and run:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 \
  scripts/capture-testflight-startup.py \
  --pymobiledevice3 /ABSOLUTE/PATH/TO/PINNED-10.7.2/pymobiledevice3 \
  --expected-build 2026.7.28 \
  --output-directory /ABSOLUTE/NEW/PRIVATE/CAPTURE-DIRECTORY
```

The safe operator sequence is:

1. Connect, unlock, and Trust/Pair the affected phone. The tool waits without
   reading the app container. Do not open TestFlight or permit an automatic app
   update before the `.28` capture; the tool rechecks the installed identity at
   arm, launch, and finalization and aborts if it changes.
2. If `FEARLESS_CAPTURE_WAITING_FOR_FORCE_QUIT` appears, force-quit Fearless
   once and leave it closed.
3. Only after `FEARLESS_CAPTURE_ARMED` appears, cold-launch Fearless exactly
   once. Do not press Retry.
4. Wait for `FEARLESS_CAPTURE_COMPLETE`. A disconnect after the stopped
   boundary, a second launch, duplicate ready marker, wrong process envelope,
   wrong installed build, or sanitizer failure aborts the window.

Only `installed-app-metadata.json`, privacy-safe NDJSON, and a capture receipt
are produced on success. `captureStatus=complete` proves capture integrity;
`devicePIDStreamStartAcknowledged=true` proves the device accepted the exact
PID-only stream even if Fearless emitted no qualifying log record;
`diagnosticSufficient=true` additionally means a deterministic privacy-safe
incident mapping was observed. A bare startup marker or process termination is
recorded but does not claim a cause. It does not qualify the hotfix for release.

The affected-phone capture is stored at
`build/diagnostics/startup-capture-2026.7.28-20260813T023458Z/`. Its receipt
SHA-256 is
`018e39b2b75191d9322f49535c17bffddbba3c4d65a927f6f3f3fbedd167f5d1`.
It contains one failed marker, no ready marker, and no observed process
termination. The failed marker followed the first retained startup/migration
record by about 205 milliseconds, which contradicts the 15/60-second timeout
paths for this launch. No stable incident code was present, so the `.28`
parameterless callback makes migration, preflight, wallet opening, and the
post-setup broken/unsupported route indistinguishable. Do not repeat the `.28`
capture or request raw logs/container data. The first `.8.10` structured
observation identified `SUBSTRATE_COMPATIBILITY_MISSING`; do not Retry it.
The in-place `.8.13` update preserved and opened the wallet but hid UIKit's
managed tab items behind the custom tab bar on iOS 26. The `.8.15` compatibility
build restored those legacy items. `.8.17` restored the redesign but omitted
usable BTC support. `.8.18` added BTC but regressed Polkaswap availability and
clean-start settings. `.8.19` restored Polkaswap but hid its swap action under
the tab bar. `.8.20` corrected the swap action but left accountless existing
wallets without a visible Bitcoin recovery path. `.8.22` added Taira but left
both app-owned networks dependent on remote catalog completion. `.8.23`
persisted those rows locally but retained stale Bitcoin presentation/service
behavior and swallowed non-missing Keychain failures. `.8.24` corrected the
Bitcoin service, logo, and secret-derivation contract but retained the wrong
Taira XOR identity. Use `.8.24` as the installed baseline, then corrected
`.8.25` for the preserved-data
qualification below.

## Internal TestFlight gate

1. Confirm the installed identity is `jp.co.soramitsu.fearlesswallet`, version
   `4.2.0`, build `2026.8.24` before the corrected successor
   update.
2. Assign build `2026.8.25` only to a true internal TestFlight group containing
   the affected phone's App Store Connect user. Do not use the similarly named
   external affected-phone group, which requires Beta App Review, and do not
   change the public beta group.
3. Install it in place through Apple's TestFlight app. Do not remove the existing
   installation or clear any data.
4. Start the first sanitized Fearless-only window with the exact command below.
   If requested, force-quit once; cold-launch only after the armed marker. Do
   not tap Retry. A failure still finalizes after the short terminal grace, but
   a ready launch remains under exact-PID observation for five full minutes:

   ```bash
   PYTHONDONTWRITEBYTECODE=1 python3 \
     scripts/capture-testflight-startup.py \
     --pymobiledevice3 /ABSOLUTE/PATH/TO/PINNED-10.7.2/pymobiledevice3 \
     --expected-build 2026.8.25 \
     --observation-seconds 900 \
     --terminal-grace-seconds 2 \
     --ready-observation-seconds 300 \
     --output-directory /ABSOLUTE/NEW/PRIVATE/FIRST-HOTFIX-CAPTURE
   ```
5. Keep Fearless open and usable for at least five continuous minutes. A living
   process is not evidence of usability. Require:
   - no failure alert and no `FEARLESS_STARTUP_FAILED` marker;
   - exactly one `FEARLESS_STARTUP_READY` marker in this launch window;
   - successful PIN entry and a working wallet route;
   - all five bottom navigation controls visible, with Portfolio, DeFi,
     Polkaswap, Cross-chain, and Settings each opening successfully;
   - Polkaswap settings loaded, a live swap quote and separate fee quote, the
     swap action fully visible and hittable above the tab bar with the keyboard
     hidden and shown, a working preview, and signing readiness, all recorded only as pass/fail
     attestations; do not submit or broadcast a swap;
   - a nonzero PI-backed Polkaswap token price visible, recorded only as a
     pass/fail attestation without the token identifier or price value;
   - with the remote chains request deliberately unavailable, native BTC and
     Taira already visible; restore connectivity before network-read checks;
   - native BTC visible in Portfolio before a chain account exists, its
     mnemonic-only setup action available, the official Bitcoin mark visible,
     the Mempool.space public endpoint working, Switch Node absent, and the
     empty chain-account ellipsis hidden;
   - on a separate test wallet that existed before the update with authentic
     stored root BIP39 entropy and no Bitcoin chain account, automatic upgrade
     provisioning succeeds and the resulting address matches
     standard BIP84; then require a successful BTC balance refresh, a valid
     BIP84 receive address, a BTC send fee quote, and signing readiness,
     recorded only as pass/fail attestations; do not broadcast funds. A raw
     Substrate seed, watch-only account, or JSON import cannot satisfy this
     attestation and must use the explicit mnemonic-only recovery route;
   - Taira Testnet and its canonical XOR row visible before a chain account
     exists, its mnemonic-only setup action available, an I105 account
     provisioned for a compatible wallet, canonical `xor#universal` resolved
     through `https://taira.sora.org`, its unconstrained `NumericSpec` and
     wallet-adapter precision `28` validated against Iroha `optimizations`
     commit `d8544f1d4d3a73c4a17873250a483208c9aafc16`, a successful Torii
     balance refresh, a visible valid I105 receive address, Taira Send
     unavailable, and the Switch Node absent and the empty chain-account
     ellipsis hidden, recorded
     only as pass/fail attestations; local derivation does not attest on-chain
     registration or funding;
   - unchanged wallet counts, logical store integrity, Keychain access, and
     settings access, recorded only as pass/fail attestations without values.
   Record the actual `previousBuildVersion` (`2026.8.24`) and
   `originalAppStoreContainerPreserved=true`; this binds the successor update
   to the still-preserved container originally installed from the App Store.
6. After the first capture completes, force-quit once more and use a new output
   directory for the second cold launch. Require exactly one ready marker, no
   failed marker/alert, successful PIN entry, a working wallet route, and all
   five bottom navigation controls/routes working again. Require a nonzero
   PI-backed Polkaswap token price, loaded Polkaswap settings, swap and fee
   quotes, a fully visible and hittable swap action, preview and signing
   readiness, plus the post-setup BTC/Taira attestations, the official Bitcoin
   mark and Mempool endpoint, absent Bitcoin/Taira Switch Node actions, hidden
   Bitcoin/Taira chain-account ellipses, and a
   stable auto-provisioned BIP84 address across relaunch
   without recording addresses, balances, transaction data, identifiers, or
   values. On both launches, the privacy-safe Taira booleans
   `tairaCanonicalXorAliasResolved`, `tairaCanonicalXorSchemaValidated`, and
   `tairaCanonicalToriiEndpointWorked` must be true; they must not contain the
   returned definition, balance, address, or payload:

   ```bash
   PYTHONDONTWRITEBYTECODE=1 python3 \
     scripts/capture-testflight-startup.py \
     --pymobiledevice3 /ABSOLUTE/PATH/TO/PINNED-10.7.2/pymobiledevice3 \
     --expected-build 2026.8.25 \
     --observation-seconds 180 \
     --terminal-grace-seconds 2 \
     --ready-observation-seconds 5 \
     --output-directory /ABSOLUTE/NEW/PRIVATE/SECOND-HOTFIX-CAPTURE
   ```
7. Store only sanitized evidence under ignored `build/` output and audit it:

   The evidence's first- and second-launch timestamps, marker counts, and
   `captureReceiptSHA256` values must match these two capture bundles. The
   auditor reads the private receipts, metadata, and sanitized logs directly;
   it rejects an unbound receipt, a short READY window, a stopped process,
   duplicate/missing markers, raw-data fields, or artifact provenance drift.
   Bind the audit to the source commit embedded in the uploaded IPA, not to a
   later host-only diagnostics commit:

   ```bash
   chmod 600 build/testflight-2026.8.25-upgrade-usability.json
   upload_receipt=/ABSOLUTE/PATH/TO/2026.8.25/testflight-internal-upload.json
   artifact_source_commit="$(jq -er '.artifactSourceCommit' "$upload_receipt")"
   PYTHONDONTWRITEBYTECODE=1 python3 \
     scripts/audit-testflight-upgrade-usability-gate.py \
     build/testflight-2026.8.25-upgrade-usability.json \
     --first-launch-capture-receipt \
       /ABSOLUTE/PRIVATE/FIRST-HOTFIX-CAPTURE/capture-receipt.json \
     --second-launch-capture-receipt \
       /ABSOLUTE/PRIVATE/SECOND-HOTFIX-CAPTURE/capture-receipt.json \
     --expected-artifact-source-commit "$artifact_source_commit"
   ```

The evidence schema is enforced by the audit's tests. It binds both the exact
`.28` base commit and the clean hotfix commit embedded in the artifact, plus
build identity, timestamps, marker counts, and boolean attestations. It must not
contain database counts, wallet names/addresses, keys, paths, or device IDs.
Run the privacy boundary self-tests before producing evidence:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 scripts/test-filter-startup-syslog.py
PYTHONDONTWRITEBYTECODE=1 python3 scripts/test-capture-testflight-startup.py
PYTHONDONTWRITEBYTECODE=1 python3 \
  scripts/test-audit-testflight-upgrade-usability-gate.py
```

## Release decision

Only after the audit passes may release review replace build `2026.7.28` in the
public beta group with `2026.8.25`. Uploading and assigning the restricted group
do not authorize changing the public beta group; that change still requires the
normal App Store Connect authorization and review trail.
