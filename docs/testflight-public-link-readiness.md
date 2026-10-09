# TestFlight Public-Link Readiness

Status: **BLOCKED / fail closed**. The public TestFlight link is enabled and
resolves to Apple's Fearless Wallet landing page, but the exact external build
is still in review. This record therefore distinguishes a shareable link from
an approved, installable build.

## Observed Snapshot

The following facts were visually observed in an authenticated Safari session
on 2026-07-16. They are a dated snapshot, not an App Store Connect API
attestation and not a promise about later Apple state:

- the signed-in provider was `Soramitsu Co., Ltd.`;
- external group `Public Beta Test` showed `120 testers` and `1 build`;
- the selected build was `4.2.0 (2026.7.15)`;
- its localized status was `審査中` (`In Review`) with 90 days until expiry;
- Public Link was enabled with a 500-tester limit and
  118 of the 500 public-link places occupied; and
- the exact public link was
  <https://testflight.apple.com/join/012KzFyD>.

The URL is intentionally committed because it is the user-requested public
distribution endpoint, not an App Store Connect credential or private signing
capability. Its SHA-256 is
`d6599b1b9c0f7e77d9dd80d9185da67c1d864be5df9a7bbf360f245b099a000c`.
No account credentials, screenshots, device identifiers, or private API
artifacts are committed with this snapshot.

## What The Public Page Proves

Safari resolved the link to an Apple-owned page titled
`Join the beta for Fearless Wallet: DeFi Wallet - TestFlight - Apple`. The page
showed the Fearless Wallet description and the `View in TestFlight` action.
That proves the public join route and app identity resolved at observation time.

It does not prove that build `4.2.0 (2026.7.15)` can currently be installed.
The generic landing page did not expose the current build identity, the build
was still in external beta review, and no clean-device installation of that
exact version/build was observed.

The machine-readable truth is therefore `linkEnabled=true` and `submittedForReview=true`.
The blocked claims are `externalBetaApproved=false`, `deviceInstallVerified=false`, and `releaseEnabled=false`.
A link resolving is not approval, and submission for review is not approval.

## Exit Evidence

Do not change the blocked state until one reviewed evidence set establishes all
of the following for the same exact build:

1. App Store Connect shows external beta approval for
   `4.2.0 (2026.7.15)`, not `In Review`, waiting, rejected, expired, or a newer
   replacement build.
2. A clean eligible device follows the public link through TestFlight and
   installs that exact version/build.
3. The install observation is recorded without credentials or stable device
   identifiers and is independently reviewed.
4. The group, link, capacity, build status, expiry, and Apple landing page are
   revalidated immediately before changing `releaseEnabled`.

An approval or install result for another group, build, app, provider, or link
does not satisfy this contract. If Apple revokes the link, changes the build, or
returns a different app page, update the observed facts and keep the state
blocked until the full same-build evidence set exists.

## Local Verification

Run:

```bash
bash ./scripts/test-testflight-public-link-readiness-audit.sh
bash ./scripts/audit-testflight-public-link-readiness.sh
```

The audit is offline and never contacts Apple. It validates the pinned dated
snapshot, its internal arithmetic and URL digest, the fail-closed claims, and
the CI/release-checklist wiring. Live state must still be re-observed because a
local audit cannot establish that App Store Connect has changed since the
snapshot.
