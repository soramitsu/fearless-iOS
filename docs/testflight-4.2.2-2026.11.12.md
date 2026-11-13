# Fearless iOS 4.2.2 (2026.11.12)

Apple accepted this build for normal App Review on 13 November 2026 at 01:21:40 UTC. App Store Connect reported `WAITING_FOR_REVIEW` with `AFTER_APPROVAL` selected. Apple will publish the version after approval.

| Release identity | Value |
| --- | --- |
| Bundle | `jp.co.soramitsu.fearlesswallet` |
| Source commit | `20204c73275b2652815613dddeb7705b9460bb8a` |
| Build and delivery ID | `f97e9735-1083-4809-810c-f3a3adf5e867` |
| App Store version | `2364da5f-9482-479e-ab6b-d60c6b171298` |
| App Review submission | `db147fe0-7b12-42d3-980b-4eb80f57bb12` |
| Signed archive tree SHA-256 | `b109df976e108b74510588530b381b58c3c8c86272375e4d258f318f7c0371ee` |
| Signed executable SHA-256 | `6a3ac56ff46638ad5940b9d6559c7ef2e254885269072c3e85c2bb5cc86ac39e` |
| Exported and uploaded IPA SHA-256 | `44a7eea652cf83f6ee58fc594d7f7accad10ea0cfe73ddabe9bb12791f0f763e` |

4.2.1 (2026.11.11), on sale since 12 November, could crash right after unlock. Since 4.2.0 the socket engine reports state changes on its own queue, so each new socket's first change arrives while the chain registry is still adding the chain list. `ChainRegistry.webSocketDidChangeState` read that list without the registry's lock and trapped with "Index out of range" when the update replaced it, as in the crash report from a TestFlight iPhone 16 Pro Max on iOS 27.2.1. 4.2.2 looks the chain up under the lock on the registry's own serial queue. It also guards the other state on that path: the chain-types map, the hot-boot check, the two network-issue listener lists and two lazily created locks. What's New adds one line above the 4.2 notes: "4.2.2 fixes a crash that could happen when opening the app."

Apple accepted the single upload. Fastlane then exited with the known local resume-file error. The upload was reconciled from the uploader's success line and delivery ID, the matching server upload, the identical temporary IPA and the later `VALID` build, and was not repeated. The App Review notes and demo account carried over unchanged from 4.2.1; only their digests were compared.

| Local validation | Result |
| --- | --- |
| Crash regression tests | On 4.2.1, five of the new tests fail (three crash the host). Thread Sanitizer reports the race at `ChainRegistry.swift:1066` through `ConnectionPool` and `FailoverChainConnection`, the device crash's frames. With the fix, 149 related tests pass under Thread Sanitizer with no reports, and the new tests pass 20 times in a row. |
| Full Debug on iOS 18.1 and iOS 27.0 | 3,780 passed, 96 skipped on each runtime, zero failures or host restarts |
| Full optimized Release | 3,708 passed, 95 skipped, zero failures or host restarts |
| Core Data release suite | All 483 passed |
| Optimized Release startup and store preservation | First launch and relaunch passed on iOS 17.5, 18.1, 26.5 and 27.0 |
| Release source checks | All 60 passed |
| Signed archive | Production signing, entitlements, dSYM UUID, deployment targets, 28 Core Data classes and 34 required resources verified |

The Debug products were built at `42dd1e2377f4a324c3019065cf332890a042ebca`. The release source differs from it only in the Core Data gate's test list and count. The optimized Release suites, the Core Data gate, the source checks, the rehearsal and the archive use the release source above.

The lifetime scanner found the same 48 candidates as 2026.11.11, but one carried a new identity. It was the `UserStorageMigrator.performMigration` copy-source candidate moved by one instruction, with identical code around it, and it was reviewed as no defect. The first rehearsal attempts stopped before launching. One required an `.xctestrun` that the scheme-based gate runs do not write. The other rejected the simulator name, as for 2026.11.11, so the runtime-only retry reused the identical app. The first iOS 18.1 Debug attempt aborted before any test because its run file lacked the toolchain library path.

The local release report is under `build/reports/ios-launch-crash-4.2.2-2026.11.12/` in the Fearless workspace. It includes the device crash report, the red and green fix evidence, the gate results, the signed archive audit and review, the upload reconciliation and the App Store Connect receipts.
