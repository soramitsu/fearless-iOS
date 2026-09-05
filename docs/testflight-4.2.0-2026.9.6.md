# TestFlight 4.2.0 (2026.9.6)

Status on 2026-09-06: release source prepared; production service configuration
is required before a signed archive and upload can be qualified. No upload of
this build has been attempted.

## Included changes and qualification

This candidate includes the completed legacy upgrade preservation fixes, native
TON/Jetton/TonConnect restoration, and the tested accessibility/layout changes.
The app, test, and package source inventory is carried from the qualified working
copy; the release-specific project changes set the build number, synchronize the
SwiftPM lockfiles, and correct build-time service configuration handling.

- iOS regression inventory: 526 unique passing Release tests.
- Repository-owned TonSwift SDK: 41 passing tests.
- Release identity contract: 43 passing cases; signed artifact contract: 59.
- TON readiness audit: 84 passing mutation cases; the general production-send
  gate remains disabled and the reviewed legacy native-account exception remains
  bound to the original key and address.
- Fastlane publishing tests: 18 passing tests / 36 assertions with pinned 2.238.0.
- Real Xcode production identity preflight passed for this version/build.
- Service configuration generation: 7 passing tests, including compiled Swift
  literal round trips and atomic write failure recovery.
- Service configuration audit and actual project-phase injection: 27 passing
  tests; the current placeholder configuration is correctly rejected.
- Device-upgrade evidence audit: 20 passing tests; startup capture: 39 passing
  tests, including the new supported build.

The authenticated App Store Connect preflight found build 2026.9.6 unused. The
existing internal group is `App Store Connect Users`, with automatic distribution
of Xcode builds enabled. Recheck build uniqueness immediately before archiving.

## Configuration blocker and fix

The local `CIKeys.generated.swift` in every available iOS working copy contained
Boolean placeholders. The legacy Sourcery invocation passed unset environment
variables as empty `--args` assignments, which generated quoted Boolean values.
The configured private pod version supplies Debug settings, not an approved
production replacement. No Debug keys have been substituted for Release keys.

The generator now renders the reviewed template from the existing environment
variable names, escapes Swift literals, leaves unset settings empty, writes the
ignored output atomically with mode 0600, and never places credentials in process
arguments or diagnostics. Google identity injection only changes the built app;
it no longer rewrites tracked plist or xcconfig files. Archive preflight rejects
missing/placeholder active service settings, and postflight verifies unchanged
configuration and the actual archived Google OAuth identity. Receipts contain
hashes and presence information, never setting values.

Provide the production CI configuration through the existing ignored
`fearless/env-vars.sh` or the build environment, then generate the ignored file
before running the audited archive wrapper. The native Google OAuth client and
callback must match; the template's web client identifier may be a separate
server client. Do not commit service configuration.

## Publication steps remaining

1. Provision and validate the production service configuration.
2. Archive the reviewed release source from its clean, exact HEAD with
   `scripts/ci/build-audited-ios-release-archive.sh`.
3. Verify the production signing identity, app groups, default Keychain access,
   storage compatibility models, configuration receipts, and archive hashes.
4. Upload the audited archive through the existing authenticated Xcode account.
5. Wait for Apple processing and verify this exact build is available to the
   existing internal tester group. Save the upload and distribution receipts.

Signed-device upgrades in place from historical releases remain the acceptance
gate before broader release. The local synthetic qualification does not replace
that device check, and TestFlight upload alone does not establish it.
