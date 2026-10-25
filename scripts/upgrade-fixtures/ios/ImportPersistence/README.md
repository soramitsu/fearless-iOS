# Import persistence ownership qualification

This runner qualifies 127 exact named methods: 66 AccountImportTests, 38 SelectedAccountSettingsTests, 15 StoredChainAccountRecordsTests, and eight StoredWalletRecordsInspectorTests. It reuses the strict artifact/result gate in `../TonRecovery/qualify.py` and its seven adversarial tests. Missing, substituted, duplicate, skipped, expected-failure, or failing results fail qualification.

The actual import controller and presenters use production import factories, SelectedWalletSettings, Core Data, and public fixture keys in an in-memory keystore. Held and failed storage writes establish acknowledgement ordering, successful key ownership after presenter/interactor deallocation, native TON rollback, retry, duplicate actions, Back, covering navigation, foreground notification, and newer wallet/metadata selection. Actual hit-tested Continue after interrupted success performs no new import or save. The per-chain follow-up uses the production conditional save under the same settings lock; concurrent wallet changes and metadata changes remain current.

Build `fearless.tests` for testing with pinned dependencies. Freeze the complete app with its embedded XCTest bundle, generated `.xctestrun`, and a `freeze.json` containing `readerCommit` and every artifact's absolute `path`, `bytes`, and `sha256`. This inventory binds the compiled source and four test-source hashes. Build for the older runtime so Xcode embeds required compatibility libraries; do not manually patch the binary.

```sh
python3 scripts/upgrade-fixtures/ios/ImportPersistence/run.py \
  --repo "$PWD" --reader /absolute/frozen-reader --out /absolute/new-results \
  --device OWNED_SIMULATOR_UUID --os 26.5
```

Run the identical frozen reader on required iOS 26.5, the newest installed runtime, and a pre-26 runtime per AGENTS.md. `--validate-only` checks existing results without running tests. The gate checks all frozen app/XCTest files, correct configured host, exact named test inventory, runtime, device, and Git source identity.

The baseline preserves four genuine failures among six cases: late successful navigation after Back/background, an error sheet after background failure, and a stale per-chain follow-up overwriting newer selection. A later zero-yield synchronous push/pop test failed its no-auto-navigation expectation without proving actual attachment changes. The final test explicitly proves import view detachment and covering view attachment before returning; no claim is made that every transient synchronous navigation-stack mutation revokes ownership.

This is bounded persistence/lifecycle coverage. The background tests invoke real notification handlers in-process; they are not external OS background tests. Generic mnemonic/raw-seed/JSON factories still have eager key-write atomicity and concurrency follow-ups; only native TON transactional rollback is qualified here. Pre-write optional Ethereum prompts, delayed external keystore responses, ordinary irregular-TON confirmation, and full system-Keychain import/restart remain separate. No complete G5 cell, release, signed/store, physical biometric, public-chain, or all-import atomicity claim is emitted.
