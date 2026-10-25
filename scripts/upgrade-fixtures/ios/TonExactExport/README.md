# Exact legacy TON export qualification

This source-bound runner exercises 101 named XCTest methods: six exact-export tests and 95 existing import, verified mnemonic ownership, presentation, seed-sharing and native TON identity regressions. It reuses the strict artifact/result gate in `../TonRecovery/qualify.py` and its seven adversarial tests. A missing, substituted, duplicated, skipped or failing test is a failed qualification.

The five irregular public phrases and expected addresses/public keys come from the exact released iOS 4.0.4 writer in the accepted IC07 checkpoint (`ios-historical-ton-v1/writer-documents-v1-27-0/historical-state.json`, app `195b0230743fa3c5fb74fbf05f4e4ee38b2d0bcf`). Current cryptography does not generate the expectations. The newline is an actual LF; the old diagnostic JSON escapes it for readable output.

Build `fearless.tests` for testing with the repository's pinned dependencies and intended simulator destination. Freeze the complete app with its embedded `fearlessTests.xctest`, the generated `.xctestrun`, and a `freeze.json` containing `readerCommit` and every file's absolute `path`, `bytes`, and `sha256`. The inventory pins the exact compiled source and test-source hashes. Older runtime builds must let Xcode embed the required Swift compatibility libraries; do not manually alter the signed app.

```sh
python3 scripts/upgrade-fixtures/ios/TonExactExport/run.py \
  --repo "$PWD" --reader /absolute/frozen-reader --out /absolute/new-results \
  --device OWNED_SIMULATOR_UUID --os 26.5
```

Repeat on the newest installed iOS runtime and one pre-26 runtime required by `AGENTS.md`. `--validate-only` rechecks existing results without running tests. The runner rejects artifact drift, missing compiled tests, a mismatched source/runtime/device, an incomplete named inventory, or a wrong test host. The clipboard-expiry method waits 61 seconds and records actual string presence/hash, original-phrase equality, elapsed time, pasteboard change counts and hasStrings before/after the data read. It retains both the original-phrase absence and empty-metadata assertions without an intervening write. Teardown clears only the unchanged item written by the test. Only public test fixtures enter that pasteboard. A prior iOS 18.1 hasStrings-only failure is retained in the evidence; later content-aware passes do not establish its cause.

The UIKit tests attach an actual controller to a simulator `UIWindowScene`, operate hit-tested controls, and inspect English, Russian and Simplified Chinese at normal/AX5 text in a 320×640 window. They prove exact UTF-8 copy and original public identity reimport with the actual factory and an in-memory keystore, and preserve the original secret bytes and backup flag. Actual old Keychain/store continuity remains the separate IC07 evidence. The local-only pasteboard option is source-verified; no cross-device clipboard test is claimed.

This checkpoint does not close ordinary shuffled-word confirmation for irregular phrases, retained removed-view callbacks after same-controller rebind, already-issued import-save lifecycle ownership, or the full fresh system-Keychain import/restart journey. No passing full TM-I2 matrix cell, physical-device biometric, signed/store, public-chain or production-release claim is emitted.
