# Fearless iOS 4.2.1 (2026.11.11)

Apple accepted this build for normal App Review on 10 November 2026 at 10:32:58 UTC. App Store Connect reported `WAITING_FOR_REVIEW` with `AFTER_APPROVAL` selected. Apple will publish the version after approval.

| Release identity | Value |
| --- | --- |
| Bundle | `jp.co.soramitsu.fearlesswallet` |
| Source commit | `098dc861e48ebdec6e5595688170cb554f8b5f15` |
| Build and delivery ID | `c2f1d77b-e5f4-4804-b5e2-6c72bc6456d3` |
| App Review submission | `329e0185-c418-4977-8419-77be27971a94` |
| Signed archive tree SHA-256 | `d3003d311f8646eedd0dd0c7d8c63a8a857e033ab3f4a091b8118a5a1a5bda0b` |
| Signed executable SHA-256 | `8cd991885d96b1585265cb46e057b5b1ecc7fd97612e263d8757dc70cbe20039` |
| Exported and uploaded IPA SHA-256 | `a9ba1cba78615e55b131d2921aaf942766774d9fe4124236eb1f1f5a9eacab43` |

Apple had rejected the previous build, 2026.11.10. Its review message was unavailable at resubmission. This build replaces it in the existing submission. Apple processed the single upload as valid and made the build available to internal TestFlight users.

When a user left PIN setup with a save pending, UIKit could deliver the disappearance callback after the save completed and navigated to the main screen. The controller now cancels that pending navigation when UIKit starts removing it from its parent. Diagnostic tests reproduced the predecessor race in 18 of 20 attempts. The fixed build passed all 40 attempts across iOS 18.1 and iOS 27.0.

| Local validation | Result |
| --- | --- |
| Full Debug on iOS 18.1 and iOS 27.0 | 3,773 passed, 96 skipped on each runtime, zero failures or host restarts |
| Full optimized Release | 3,701 passed, 95 skipped, zero failures or host restarts |
| Core Data release suite | All 478 passed |
| Optimized Release startup and store preservation | First launch and relaunch passed on iOS 17.5, 18.1, 26.5 and 27.0 |
| Release source checks | All 60 accounted for. One Fastlane check passed on rerun with the pinned version. |
| Signed archive | Production signing, entitlements, dSYM UUID, deployment targets, 28 Core Data classes and 34 required resources verified |

The Debug products were built at `4fc2b3a1aabd0fa9eadfef646816d3277008f82b` with the same checked app and test sources. The optimized Release suites, rehearsal and archive use the pinned release source above. The signed Solana retry retains the signature before destroying its snapshot. All 48 heuristic scan sites matched the predecessor. Archive cleanup restored the generated keyless configuration.

The first rehearsal preflight rejected the simulator’s display name. The corrected run verified the actual device types and reused the identical app. The initial binary inspection also rejected Xcode’s Swift compatibility library. The corrected inspection verified both iOS device slices and their deployment targets. Apple reported a successful upload before Fastlane failed to write a local resume file. Server processing, the delivery ID and both IPA hashes confirmed acceptance without a second upload.

The owner confirmed the in-place update on an iPhone 17 Pro Max. Two device APIs confirmed that 2026.11.11 was installed. Physical cold-launch, PIN and wallet-visibility observations were pending when the owner requested immediate release. The broader physical upgrade audit was unqualified at submission. Earlier sr25519 coverage comprised 11 passing optimized Debug cases on a separate device test host with matching crypto inputs.

The local release report is under `build/reports/ios-public-release-4.2.1-2026.11.11/` in the Fearless workspace. It includes the signed artifact audit, upload reconciliation, TestFlight membership, physical installation metadata and the App Review transaction in `asc-resubmit-rejected-version.json`.
