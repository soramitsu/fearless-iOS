# Native TON spacing recovery qualification

This is the bounded follow-on to `HistoricalWriter`'s IC07 cohort. The exact
released 4.0.4 writer demonstrated that repeated spaces, leading/trailing spaces,
and embedded newlines can produce a different healthy TON key. The recovery flow
must preserve the input, derive both valid interpretations, and require an
explicit address choice when their identities differ. It must not write either
candidate merely because the user pressed Continue.

`inventory.json` pins the compiled test source and all 53 required method names:
44 `AccountImportTests` and nine `LegacyNativeTonUpgradeTests`. The test source
contains the public historical identities; expected secrets are not generated
with the current implementation. The five spacing variants, canonical phrase,
and capitalization case retain the previously accepted historical provenance.

The UIKit tests use real sheet controls in an attached window, at 320×640 points
and AX5 in English, Russian, and Simplified Chinese. They check both selected
addresses, duplicate clicks, Cancel during its dismissal animation, external
dismissal, backgrounding, navigation Back, and stale/duplicate preparation
replies. Actual import operations verify selected private-key identity and exact
stored phrase bytes through an in-memory keystore seam. A canonical phrase needs
no chooser. Existing corruption, signing, and rollback regressions also run.

## Reproduce

Build `fearless.tests` with the repository's pinned dependencies and
`build-for-testing`, selecting the actual simulator destination. Set both
`SOURCE_PACKAGES_DIR` and `-clonedSourcePackagesDirPath` to the same checked cache.
Use the simulator-only test entitlements from the historical writer harness.
Do not substitute device signing or disable dependency guards.

Freeze the app, its embedded XCTest bundles, and generated `.xctestrun` under
`Products`. `freeze.json` has `readerCommit` and a nonempty `files` array with
absolute `path`, `bytes`, and `sha256` for every file in Products. The accepted
evidence provides the executed build commands and freeze script. Frozen app and
test binaries must be from the `compiledSourceCommit` in the inventory.

```sh
python3 scripts/upgrade-fixtures/ios/TonRecovery/qualify.py \
  --repo /absolute/path/to/checkout \
  --reader /absolute/path/to/frozen-reader \
  --out /absolute/path/to/new-run \
  --device SIMULATOR-UUID --os 26.5 --run
```

Omit `--run` to validate an existing run with `run.json`, the configured
`.xctestrun`, and the unmodified `xcresulttool get test-results summary` and
`tests` JSON. Validation checks the named inventory, every result, counts,
runtime/device, Git test-source bytes, and the complete frozen app/XCTest file
inventory. Missing, unlisted, duplicate, skipped, failed, source-mismatched, and
artifact-drift cases fail. `test_qualify.py` exercises those rejection paths.

Build for iOS 18.1 separately: Xcode 27's Swift compatibility embedding considers
the selected destination OS. Reusing the iOS 27 artifact on 18.1 failed to load
`libswiftCompatibilitySpan.dylib`. Rebuilding the unchanged source for 18.1
automatically added `--back-deploy-swift-span` and embedded the library. No
post-build binary injection or production build-setting workaround was used.

## Boundaries

The required simulator is iOS 26.5; 27.0 and 18.1 are additional UIKit evidence.
This checkpoint does not qualify physical devices, signed/store artifacts,
public-chain transactions, or the complete TM-I2 matrix. Historical actual
system-Keychain continuity remains in IC07; the fresh selected-candidate UI test
uses an in-memory keystore. No new end-to-end fresh import through system Keychain
is claimed. U6 remains partial, with no device-biometry claim.

Pending discovery and the chooser are owned by the current view and application
lifecycle. Navigation after an already-issued persistence operation remains a
separate follow-up. Exact irregular-phrase export presentation/copy and its
complete export-to-import journey also remain separate. The AX5 controls require
scrolling; the ambiguous chooser has no separate normal-text visual matrix here.
