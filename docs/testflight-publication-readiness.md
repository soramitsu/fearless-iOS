# TestFlight Publication Readiness

Status: **BLOCKED only on exact Apple-delivered install/rehearsal and symbolication follow-up**

This document records the sanitized, reviewable publication snapshot for the
migration-fixed Fearless Wallet iOS build. It does not contain App Store
credentials, signing secrets, wallet data, device data, or a private tester
handoff.

## Exact Published Build

- Artifact source commit:
  `f56b7b896344cfded39456217097747ef9efeacf`.
- Bundle and version:
  `jp.co.soramitsu.fearlesswallet`, `4.2.0 (2026.7.26)`.
- Pre-upload archive tree SHA-256:
  `301f19a4f1232fb05719d85b825ac081196fa5fb6988b58011b7569a4bd9e6fa`.
- Executable SHA-256:
  `cf0318792fc361bbd8704b21b6e1a08c4d81897f23492e4a807eab7f22403568`.
- Signed-archive audit receipt SHA-256:
  `1dbf38740b38403dde9cc7d4b1710cd28fdd5dc6f6f25990a7102020f11d1abc`.
- Preserved-data archive rehearsal result SHA-256:
  `418d22cdd9e673ddfa1f47a49c666df11a740aac6737f6ef2b0328fa1b6a8641`.

Xcode uploaded the exact archive successfully at `2026-07-26T13:16:00Z`.
Its only archive mutation was the normal `Distributions` receipt in
`Info.plist`. Removing that receipt from a copy reconstructed the pre-upload
tree hash, while the embedded app signature and executable hash remained
unchanged.

## External TestFlight State

The authenticated App Store Connect observation at
`2026-07-26T13:26:11Z` records:

- `4.2.0 (2026.7.26)` is `Testing`;
- external group `Public Beta Test` has stable identifier
  `9410949d-b468-40e5-b2f4-24055e65d270`;
- the group contains the exact build and showed `122` testers, `2` builds, and
  `120/500` public-link places used;
- automatic tester notification was enabled; and
- the anyone-with-the-link URL is
  `https://testflight.apple.com/join/012KzFyD`.

An unauthenticated Safari request resolved that URL to Apple's
`Fearless Wallet: DeFi Wallet` page and exposed the TestFlight deep link.
Tester and build counts are a dated snapshot and can change; current App Store
Connect state must be revalidated for a later production release decision.

## Evidence Boundary

The raw post-upload, publication, and physical rehearsal attestations are in
ignored `build/` output. Their exact SHA-256 values are copied into the tracked
manifest, but those ignored files must not be treated as canonical release source. The tracked
`config/testflight-publication-readiness.json` is the sanitized public contract
reviewed by the offline audit.

The publication snapshot proves successful upload, external testing, exact
group assignment, public-link enablement, Apple landing-page resolution, and
the pre-publication preserved-data archive rehearsal. It does not prove that
the Apple-delivered TestFlight package has replaced the locally installed
Developer App on the affected phone.

## Symbolication Follow-up

The main application dSYM is present. Xcode nevertheless warned about
`MPQRCoreSDK.framework`, `blake2lib.framework`, `libed25519.framework`, and
`sr25519lib.framework`.

The dSYM warnings cannot alter install, launch, or Core Data migration runtime
behavior. The three crypto framework warnings correspond to static-stub
packaging while their useful symbols are linked into the main app image.
`MPQRCoreSDK.framework` is the remaining runtime framework without a matching
vendor dSYM, so third-party QR crash frames can have degraded symbolication.
Obtain the matching vendor dSYM or record an explicit reviewed production
acceptance before marking symbolication follow-up complete.

## Remaining Device Gate

Update the existing installation through the TestFlight app on the preserved-
data physical iPhone. Do not uninstall the app or clear its container. Then:

1. verify the installed identity is Apple/TestFlight-distributed build
   `4.2.0 (2026.7.26)`;
2. preserve the database UUIDs, protected row counts, and semantic digest;
3. run five terminate-and-cold-launch cycles with the full observation window;
4. rerun SQLite `quick_check` and compare every protected fingerprint; and
5. confirm there is no new Fearless crash report.

Until that succeeds,
`exactAppleDeliveredInstallVerified=false`,
`preservedDataPostInstallRehearsalVerified=false`, and
`releaseEnabled=false` remain mandatory.

## Offline Verification

Run:

```bash
bash ./scripts/test-testflight-publication-readiness-audit.sh
bash ./scripts/audit-testflight-publication-readiness.sh
```

The audit is offline. It validates a dated, content-addressed publication
snapshot and deliberately does not contact Apple or infer current tester
capacity from an old observation.
