# Fearless TestFlight release lanes

This configuration publishes only a pre-audited production archive and then
verifies the exact build's internal TestFlight assignment. It does not create
or modify external groups, public links, testers, signing assets, or API keys.

## One-time authentication

Preferred: create an App Store Connect API key with App Manager or Admin access,
keep its `.p8` file outside this repository, and copy `.env.example` to the
ignored `fastlane/.env`. Fill in the key ID, optional issuer ID, key path, and
tester email. The tester email is never written to a receipt; only its SHA-256
digest is retained.

An Apple-ID session is supported as a fallback by setting both `FASTLANE_USER`
and `FASTLANE_SESSION`. Generate the session with `fastlane spaceauth`. A future
binary upload also requires `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD` for
Transporter; that password alone cannot perform or verify group assignment.
Xcode's signed-in session is not reusable by Fastlane.
Set `FASTLANE_ITC_TEAM_ID` as well when the Apple account belongs to multiple
App Store Connect teams, so unattended runs cannot stop at a team prompt.

The wrapper requires the reviewed Homebrew Fastlane version and bypasses the
repository-root CocoaPods Gemfile, which intentionally supports Ruby 2.6:

```sh
brew install fastlane
scripts/fastlane.sh --version
```

`fastlane/Gemfile` and its lockfile are provided for environments that install
a separate Ruby 3.2+ bundle. Do not add Fastlane to the root Gemfile.

## Finish the already uploaded build

Use this for `4.2.0 (2026.8.33)`. It waits for that exact build, rejects invalid
processing state or any existing external assignment, resolves an exact
internal group that already contains the configured tester, assigns the build,
re-reads App Store Connect, and writes a mode-0600 publication receipt.

```sh
scripts/fastlane.sh ios finalize_existing \
  version:4.2.0 \
  build:2026.8.33
```

If the tester belongs to more than one internal group, set
`TESTFLIGHT_INTERNAL_GROUP_ID` to the exact internal group ID. Group names are
never accepted as identifiers.

## Publish a new audited archive

The lane refuses to upload if the exact version/build already exists. It checks
the archive tree against the signed audit, exports and verifies the IPA identity,
uploads without Pilot group matching, immediately records Apple's accepted
upload, waits for processing, then invokes the same strict internal finalizer.

```sh
TESTFLIGHT_ARCHIVE=/absolute/path/fearless.xcarchive \
TESTFLIGHT_SIGNED_AUDIT=/absolute/path/signed-archive-audit.json \
scripts/fastlane.sh ios publish_archive \
  version:4.2.0 \
  build:2026.8.34
```

Receipts live under `build/upload/<version>-<build>-<commit>/`. The original
signed-archive and upload receipts remain immutable; finalization writes a
separate receipt containing their SHA-256 digests.

## Contract tests

```sh
bash scripts/test-fastlane-testflight-contract.sh
```
