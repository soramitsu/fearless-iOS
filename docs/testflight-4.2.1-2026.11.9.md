# TestFlight 4.2.1 (2026.11.9)

Uploaded on 8 November 2026. App Store Connect finished processing the build as
`VALID`; internal status is `IN_BETA_TESTING`. The existing **App Store Connect
Users** group contains the build. No external group was assigned.

- Bundle: `jp.co.soramitsu.fearlesswallet`; App Store Connect app: `1537251089`.
- Source: `6a7ebf5f6ff35c383f7de1b0827c03c87dc5fcbb` on
  `hotfix/4.2.0-polkaswap-usability`.
- PIN fix: `22713d002b139eea691ec86591c187da704f8622`, merged with the current
  release line before the build-number change.
- Delivery/build ID: `05b37a0c-319e-42d4-b3f6-9bfb9c33ccea`.
- The App Review submission remains 4.2.1 (2026.11.8), waiting for review with
  manual release. This upload did not replace it.

The PIN keypad restores 72-point normal-size keys, comfortable spacing and
vertical centering. Short screens and large text can scroll without hiding
controls. Input survives layout and text-size changes.

## Local validation

The 13 PIN continuity and localized persistence/retry tests passed on iOS 27.0,
18.1 and 18.4 at the PIN fix commit (39 executions, no failures or skips).
All 13 passed again on iOS 27.0 at the exact release source above. The PIN
implementation and tests are identical across those commits.

Build-number checks and adversarial tests, 20 upgrade-evidence tests, 40 startup
capture tests, and the archive signing/provenance contract tests passed. The
signed archive passed production identity, service-configuration, historical
storage compatibility, signing, entitlements, dSYM and artifact-integrity audits.
Validation was local; hosted CI was not a release prerequisite.

## Artifact receipts

- Archive SHA-256: `3641c3707aa60fa4c4ebb1fc8903fc0f27d096b2c38a7f9974507a433363eba7`.
- Executable SHA-256: `66fbe8c8dd7e219d2815b9bd7a28ff2dbad0f21e98599b343997b16f86ca9b5b`.
- Uploaded IPA SHA-256: `acbb04355cf71ca4f53a148d79c3324ea819488dfc7504c381e02c78b4e4449c`.

Evidence is retained in
`/Users/takemiyamakoto/dev/fearless/build/reports/ios-pin-testflight-20261108/`.
The signed archive, IPA, export receipt and upload receipt are under
`release/6a7ebf5f6f-20261108T081618Z/`. Server verification is recorded in
`asc-testflight-verification-2026.11.9.json`.

Apple accepted the upload, but Fastlane returned exit 1 for the local
`CDUploaderStateInfoResumeFilePath` error. No retry was sent. The recovered
upload receipt binds Apple's delivery and final `VALID` status to the exact
audited archive, exported IPA and retained temporary upload copy.

Temporary production service settings were removed after the archive, and the
ignored generated configuration was restored to its keyless state.
