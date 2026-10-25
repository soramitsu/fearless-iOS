import CryptoKit
import Security
import XCTest
import SSFUtils
import RobinHood
import SSFRuntimeCodingService
import IrohaCrypto
@testable import fearless

final class MutationAuthorizationTests: XCTestCase {
    private let intent = String(repeating: "a", count: 64)

    func testSharedAndroidVectorsVerifyWithCryptoKit() throws {
        let fixture = try Fixture.load()
        XCTAssertTrue(fixture.testOnly)
        XCTAssertEqual(fixture.vectors.count, 9)
        let verifier = try fixture.verifier()
        for vector in fixture.vectors {
            if vector.expectedValid {
                let verified = try verifier.verify(vector.token, now: 1_800_000_010)
                XCTAssertEqual(verified.payloadSha256.count, 64, vector.name)
            } else {
                XCTAssertThrowsError(try verifier.verify(vector.token, now: 1_800_000_010), vector.name)
            }
        }
    }

    func testClosedCanonicalPayloadRejectsSignedAlternativeEncodings() throws {
        let fixture = try Fixture.load()
        let original = try fixture.payload("valid_xcm_enabled")
        let invalid = [
            original.replacingOccurrences(of: "\"schema\":\"1\"", with: "\"schema\":1"),
            original.replacingOccurrences(of: "\"revision\":\"42\"", with: "\"revision\":\"042\""),
            original.replacingOccurrences(of: "\"revision\":\"42\"", with: "\"revision\":\"9223372036854775808\""),
            original.replacingOccurrences(of: "\"revision\":\"42\"", with: "\"revision\":\"0\""),
            original.replacingOccurrences(of: "\"xcm\":true", with: "\"xcm\":1"),
            original.replacingOccurrences(of: "\"xcm\":true", with: "\"xcm\":true,\"xcm\":true"),
            original.replacingOccurrences(of: "\"xcm\":true", with: "\"xcm\":true,\"unknown\":false"),
            original.replacingOccurrences(of: "\"schema\":\"1\"", with: "\"schema\":\"1\",\"schema\":\"1\""),
            original.replacingOccurrences(of: "\"schema\":\"1\"", with: "\"schema\":\"1\",\"extra\":true"),
            original.replacingOccurrences(of: "jp.co", with: "jp\\u002eco"),
            original.replacingOccurrences(of: "production", with: "staging"),
            " " + original, original + "\n", "\u{feff}" + original,
            original.replacingOccurrences(of: "1800000900", with: "1800000901"),
            original.replacingOccurrences(of: "1800000900", with: "1800000000"),
            original.replacingOccurrences(of: "1800000900", with: "253402300800")
        ]
        for payload in invalid {
            XCTAssertThrowsError(try fixture.verifier().verify(fixture.sign(payload), now: 1_800_000_010))
        }
    }

    func testWireBoundariesKeyDomainAudienceVersionsAndManifestAreBound() throws {
        let fixture = try Fixture.load()
        let token = try fixture.token("valid_xcm_enabled")
        for malformed in ["", token + "=", token + ".", token + "\n", " " + token,
                          String(repeating: "A", count: 8193), token.replacingOccurrences(of: "FWMA1", with: "FWMA2")] {
            XCTAssertThrowsError(try fixture.verifier().verify(malformed, now: 1_800_000_010))
        }
        let payload = try fixture.payload("valid_xcm_enabled")
        XCTAssertThrowsError(try fixture.verifier().verify(fixture.sign(payload, domain: "Other\n"), now: 1_800_000_010))
        for verifier in [
            try fixture.verifier(keys: [:]),
            try fixture.verifier(audience: "jp.co.soramitsu.fearlesswallet"),
            try fixture.verifier(version: 229), try fixture.verifier(version: 231),
            try fixture.verifier(policy: String(repeating: "f", count: 64)),
            try fixture.verifier(routes: String(repeating: "f", count: 64))
        ] {
            XCTAssertThrowsError(try verifier.verify(token, now: 1_800_000_010))
        }
        XCTAssertNoThrow(try fixture.verifier().verify(token, now: 1_799_999_940))
        for timestamp: Int64 in [-1, 1_799_999_939, 1_800_000_900, 253_402_300_800, .max] {
            XCTAssertThrowsError(try fixture.verifier().verify(token, now: timestamp))
        }
    }

    func testCompiledApprovalAndFreshProcessFetchAreBothRequired() throws {
        let harness = try Harness()
        XCTAssertFalse(harness.authority.isAllowed(.xcm))
        try harness.enable()
        XCTAssertTrue(harness.authority.isAllowed(.xcm))
        XCTAssertFalse(harness.authority.isAllowed(.polkamarkt))
        XCTAssertTrue(harness.authority.isAllowed(.xcm))
        let restart = try harness.newAuthority()
        XCTAssertFalse(restart.isAllowed(.xcm))
        try restart.acceptFreshResponse(harness.fixture.token("valid_xcm_enabled"))
        XCTAssertTrue(restart.isAllowed(.xcm))
        let unapproved = try harness.newAuthority(compiled: [])
        try unapproved.acceptFreshResponse(harness.fixture.token("valid_xcm_enabled"))
        XCTAssertFalse(unapproved.isAllowed(.xcm))
    }

    func testRollbackAndSameRevisionSubstitutionRemainDeniedAcrossRestart() throws {
        let harness = try Harness()
        try harness.enable()
        XCTAssertThrowsError(try harness.authority.acceptFreshResponse(harness.fixture.token("valid_all_denied")))
        XCTAssertFalse(harness.authority.isAllowed(.xcm))
        try harness.authority.acceptFreshResponse(harness.fixture.token("valid_next_revision_revoked"))
        let restart = try harness.newAuthority()
        XCTAssertThrowsError(try restart.acceptFreshResponse(harness.fixture.token("valid_xcm_enabled")))
        XCTAssertFalse(restart.isAllowed(.xcm))
    }

    func testLeasesBindIntentAndCannotSurviveFailureRevocationOrAnotherAuthority() throws {
        let harness = try Harness()
        try harness.enable()
        let lease = try harness.authority.lease(for: .xcm, intentSha256: intent)
        XCTAssertThrowsError(try harness.authority.lease(for: .xcm, intentSha256: "not-a-digest"))
        XCTAssertThrowsError(try harness.authority.check(lease, intentSha256: String(repeating: "b", count: 64)))
        try harness.authority.check(lease, intentSha256: intent)
        try harness.enable() // Identical refresh preserves a still-valid lease.
        try harness.authority.check(lease, intentSha256: intent)
        harness.authority.refreshFailed()
        try harness.enable()
        XCTAssertThrowsError(try harness.authority.check(lease, intentSha256: intent))
        let newLease = try harness.authority.lease(for: .xcm, intentSha256: intent)
        let other = try harness.newAuthority()
        try other.acceptFreshResponse(harness.fixture.token("valid_xcm_enabled"))
        XCTAssertThrowsError(try other.check(newLease, intentSha256: intent))
        try harness.authority.acceptFreshResponse(harness.fixture.token("valid_next_revision_revoked"))
        var submissions = 0
        XCTAssertThrowsError(try harness.authority.withAuthorizedSubmission(newLease, intentSha256: intent) { submissions += 1 })
        XCTAssertEqual(submissions, 0)
    }

    func testMonotonicExpiryAndClockRollbackCannotExtendSignedLifetime() throws {
        let harness = try Harness()
        try harness.enable()
        harness.clock.continuous += 890
        // Hold wall time still: continuous expiry is independently enforced.
        XCTAssertFalse(harness.authority.isAllowed(.xcm))
        harness.clock.continuous = 100
        XCTAssertFalse(harness.authority.isAllowed(.xcm)) // No resurrection.
        XCTAssertThrowsError(try harness.enable())
        let wallClockHarness = try Harness()
        try wallClockHarness.enable()
        wallClockHarness.clock.wall += 100
        XCTAssertTrue(wallClockHarness.authority.isAllowed(.xcm)) // Persist maximum observed time.
        wallClockHarness.clock.wall -= 61
        XCTAssertFalse(wallClockHarness.authority.isAllowed(.xcm))
        XCTAssertThrowsError(try wallClockHarness.newAuthority().acceptFreshResponse(wallClockHarness.fixture.token("valid_xcm_enabled")))
    }

    func testIdenticalRefreshNeverExtendsExistingContinuousDeadline() throws {
        let harness = try Harness()
        try harness.enable()
        harness.clock.continuous += 880
        try harness.enable() // Server repeats token; local wall clock is frozen.
        harness.clock.continuous += 10
        XCTAssertFalse(harness.authority.isAllowed(.xcm))
        harness.authority.refreshFailed()
        XCTAssertThrowsError(try harness.enable())
        XCTAssertFalse(harness.authority.isAllowed(.xcm))
    }

    func testFutureIssueTimeSkewCannotGrantMoreThanFifteenContinuousMinutes() throws {
        let harness = try Harness()
        harness.clock.wall = 1_799_999_940 // Accepted 60-second future-iat skew.
        try harness.enable()
        harness.clock.continuous += 899
        XCTAssertTrue(harness.authority.isAllowed(.xcm))
        harness.clock.continuous += 1
        XCTAssertFalse(harness.authority.isAllowed(.xcm))
        XCTAssertThrowsError(try harness.enable())
    }

    func testWallExpiryInvalidClockAndMalformedRefreshImmediatelyInvalidate() throws {
        let harness = try Harness()
        try harness.enable()
        harness.clock.wall = 1_800_000_900
        XCTAssertFalse(harness.authority.isAllowed(.xcm))
        harness.clock.wall = 1_800_000_010
        XCTAssertThrowsError(try harness.enable())
        XCTAssertThrowsError(try harness.newAuthority().acceptFreshResponse(harness.fixture.token("valid_xcm_enabled")))
        let second = try Harness()
        try second.enable()
        second.clock.continuous = .nan
        XCTAssertFalse(second.authority.isAllowed(.xcm))
        second.clock.continuous = 100
        XCTAssertFalse(second.authority.isAllowed(.xcm))
        try second.enable()
        XCTAssertThrowsError(try second.authority.acceptFreshResponse("invalid"))
        XCTAssertFalse(second.authority.isAllowed(.xcm))
    }

    func testDurableWriteFailureNeverGrantsEvenIfWriteCommittedBeforeError() throws {
        for commitBeforeError in [false, true] {
            let harness = try Harness()
            harness.store.failSave = true
            harness.store.commitBeforeError = commitBeforeError
            XCTAssertThrowsError(try harness.enable())
            XCTAssertFalse(harness.authority.isAllowed(.xcm))
            harness.store.failSave = false
            XCTAssertThrowsError(try harness.enable()) // Poison this uncertain writer.
            let restart = try harness.newAuthority()
            XCTAssertFalse(restart.isAllowed(.xcm))
            try restart.acceptFreshResponse(harness.fixture.token("valid_xcm_enabled"))
            XCTAssertTrue(restart.isAllowed(.xcm))
        }
    }

    func testUnreadableHighWaterCannotBeInterpretedAsFirstInstallation() throws {
        let harness = try Harness()
        harness.store.failLoad = true
        XCTAssertThrowsError(try harness.newAuthority())
        harness.store.failLoad = false
        harness.store.value = MutationAuthorizationHighWater(revision: 0, payloadSha256: "", maximumWallSeconds: 0)
        XCTAssertThrowsError(try harness.newAuthority())
    }

    func testFinalEnqueueIsSerializedWithRevocation() throws {
        let harness = try Harness()
        try harness.enable()
        let lease = try harness.authority.lease(for: .xcm, intentSha256: intent)
        let started = DispatchSemaphore(value: 0)
        let finishEnqueue = DispatchSemaphore(value: 0)
        let revoked = DispatchSemaphore(value: 0)
        let complete = expectation(description: "enqueue completes")
        DispatchQueue.global().async {
            defer { complete.fulfill() }
            do {
                try harness.authority.withAuthorizedSubmission(lease, intentSha256: lease.intentSha256) {
                    started.signal()
                    XCTAssertEqual(finishEnqueue.wait(timeout: .now() + 3), .success)
                }
            } catch { XCTFail("Authorized enqueue unexpectedly failed") }
        }
        XCTAssertEqual(started.wait(timeout: .now() + 3), .success)
        DispatchQueue.global().async {
            harness.authority.refreshFailed()
            revoked.signal()
        }
        XCTAssertEqual(revoked.wait(timeout: .now() + 0.05), .timedOut)
        finishEnqueue.signal()
        wait(for: [complete], timeout: 3)
        XCTAssertEqual(revoked.wait(timeout: .now() + 3), .success)
        XCTAssertFalse(harness.authority.isAllowed(.xcm))
    }

    func testDelayedRevisionPersistenceCannotActivateExpiredToken() throws {
        for continuousOnly in [false, true] {
            let harness = try Harness()
            harness.store.afterSave = {
                if continuousOnly { harness.clock.continuous += 900 } else { harness.clock.wall += 900 }
                harness.store.afterSave = nil
            }
            XCTAssertThrowsError(try harness.enable())
            XCTAssertFalse(harness.authority.isAllowed(.xcm))
        }
    }

    func testDelayedHighWaterPersistencePreventsFinalHandoff() throws {
        for continuousOnly in [false, true] {
            let harness = try Harness()
            try harness.enable()
            let lease = try harness.authority.lease(for: .xcm, intentSha256: intent)
            harness.clock.wall += 1
            harness.store.afterSave = {
                if continuousOnly { harness.clock.continuous += 900 } else { harness.clock.wall += 900 }
                harness.store.afterSave = nil
            }
            var writes = 0
            XCTAssertThrowsError(try harness.authority.withAuthorizedSubmission(lease, intentSha256: intent) { writes += 1 })
            XCTAssertEqual(writes, 0)
            XCTAssertFalse(harness.authority.isAllowed(.xcm))
        }
    }

    func testRepeatedSlowPersistenceFailsClosedInBoundedAttempts() throws {
        let harness = try Harness()
        try harness.enable()
        let lease = try harness.authority.lease(for: .xcm, intentSha256: intent)
        harness.clock.wall += 1
        var saves = 0
        harness.store.afterSave = { saves += 1; harness.clock.wall += 1 }
        var writes = 0
        XCTAssertThrowsError(try harness.authority.withAuthorizedSubmission(lease, intentSha256: intent) { writes += 1 })
        XCTAssertEqual(writes, 0)
        XCTAssertEqual(saves, 3)
    }

    func testSmallRollbackCannotReviveExpiryObservedDuringPersistence() throws {
        let harness = try Harness()
        try harness.enable()
        harness.clock.wall = 1_800_000_900
        harness.store.afterSave = { harness.clock.wall -= 1; harness.store.afterSave = nil }
        XCTAssertFalse(harness.authority.isAllowed(.xcm))
        XCTAssertThrowsError(try harness.enable())
        let restart = try harness.newAuthority()
        XCTAssertThrowsError(try restart.acceptFreshResponse(harness.fixture.token("valid_xcm_enabled")))
    }

    func testAuthorityLockWaitPrecedesFinalClockSample() throws {
        let harness = try Harness()
        try harness.enable()
        let lease = try harness.authority.lease(for: .xcm, intentSha256: intent)
        let locked = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let holderDone = expectation(description: "prior operation completes")
        DispatchQueue.global().async {
            defer { holderDone.fulfill() }
            do {
                try harness.authority.withAuthorizedSubmission(lease, intentSha256: lease.intentSha256) {
                    locked.signal()
                    XCTAssertEqual(release.wait(timeout: .now() + 3), .success)
                }
            } catch { XCTFail("Prior handoff unexpectedly failed") }
        }
        XCTAssertEqual(locked.wait(timeout: .now() + 3), .success)
        let queued = DispatchSemaphore(value: 0)
        let denied = expectation(description: "expired queued operation")
        DispatchQueue.global().async {
            queued.signal()
            do {
                try harness.authority.withAuthorizedSubmission(lease, intentSha256: lease.intentSha256) {
                    XCTFail("expired handoff")
                }
                XCTFail("Expired authority unexpectedly granted")
            } catch { XCTAssertEqual(error as? MutationAuthorizationError, .expired) }
            denied.fulfill()
        }
        XCTAssertEqual(queued.wait(timeout: .now() + 3), .success)
        harness.clock.continuous += 900
        release.signal()
        wait(for: [holderDone, denied], timeout: 3)
    }

    func testKeychainStoreUsesIsolatedDeviceLocalNamespaceAndAtomicUpdate() throws {
        let mock = KeychainMock()
        let store = try mock.store()
        XCTAssertNil(try store.load())
        let record = MutationAuthorizationHighWater(revision: 42, payloadSha256: intent, maximumWallSeconds: 100)
        try store.save(record)
        XCTAssertEqual(try store.load(), record)
        XCTAssertEqual(mock.adds, 1)
        let next = MutationAuthorizationHighWater(revision: 43, payloadSha256: intent, maximumWallSeconds: 200)
        try store.save(next)
        XCTAssertEqual(try store.load(), next)
        XCTAssertEqual(mock.adds, 1)
        XCTAssertThrowsError(try store.save(record))
        XCTAssertEqual(
            mock.lastAttributes?[kSecAttrAccessible as String] as? String,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
        )
        XCTAssertEqual(mock.lastQuery?[kSecAttrSynchronizable as String] as? Bool, false)
        XCTAssertEqual(mock.lastQuery?[kSecAttrAccount as String] as? String, "test.fearless")
        XCTAssertEqual(
            mock.lastQuery?[kSecAttrService as String] as? String,
            "io.fearlesswallet.mutation-authorization.v1"
        )
    }

    func testKeychainLockedCorruptAndWriteFailureDenyWithoutResettingState() throws {
        let mock = KeychainMock()
        let store = try mock.store()
        mock.readError = errSecInteractionNotAllowed
        XCTAssertThrowsError(try store.load())
        mock.readError = nil
        for data in [Data("{}".utf8), Data(repeating: 1, count: 1025)] {
            mock.data = data
            XCTAssertThrowsError(try store.load())
        }
        mock.data = nil
        mock.writeError = errSecInteractionNotAllowed
        XCTAssertThrowsError(try store.save(MutationAuthorizationHighWater(revision: 1, payloadSha256: intent, maximumWallSeconds: 1)))
        XCTAssertNil(mock.data)
        XCTAssertThrowsError(try MutationAuthorizationKeychainStore(audience: "bad audience"))
    }

    func testSystemClockUsesContinuousTimeAndFiveMinuteRefresh() {
        let first = MutationAuthorizationClock.system()
        let second = MutationAuthorizationClock.system()
        XCTAssertGreaterThan(first.wallSeconds, 0)
        XCTAssertTrue(first.continuousSeconds.isFinite)
        XCTAssertGreaterThanOrEqual(second.continuousSeconds, first.continuousSeconds)
        XCTAssertEqual(MutationAuthorizationAuthority.refreshInterval, 300)
    }

    func testReleaseBindingRequiresExactApplicationBuildPolicyAndRouteFiles() throws {
        let fixture = try Fixture.load()
        let inputs = try releaseInputs(fixture)
        let verifier = try MutationAuthorizationReleaseBinding.verifier(
            policyData: inputs.policy, trustData: inputs.trust, routeManifestData: inputs.routes,
            applicationId: "jp.co.soramitsu.fearlesswallet", bundleVersion: "2026.8.34",
            routeFile: { name in
                XCTAssertEqual(name, "mutation_route_inventory.json")
                return inputs.routeFile
            }
        )
        XCTAssertEqual(verifier.context.appVersion, 20_260_834)
        XCTAssertEqual(verifier.context.compiledCapabilities, [.xcm])
        let payload = try fixture.payload("valid_xcm_enabled")
            .replacingOccurrences(of: "jp.co.soramitsu.fearless", with: "jp.co.soramitsu.fearlesswallet")
            .replacingOccurrences(of: "\"230\"", with: "\"20260834\"")
            .replacingOccurrences(of: String(repeating: "1", count: 64), with: verifier.context.policySha256)
            .replacingOccurrences(of: String(repeating: "2", count: 64), with: verifier.context.routeManifestSha256)
        XCTAssertNoThrow(try verifier.verify(fixture.sign(payload), now: 1_800_000_010))
        for (audience, version, file) in [
            ("other.wallet", "2026.8.34", inputs.routeFile),
            ("jp.co.soramitsu.fearlesswallet", "2026.8.35", inputs.routeFile),
            ("jp.co.soramitsu.fearlesswallet", "2026.8.34", Data("substitution".utf8))
        ] {
            XCTAssertThrowsError(try MutationAuthorizationReleaseBinding.verifier(
                policyData: inputs.policy, trustData: inputs.trust, routeManifestData: inputs.routes,
                applicationId: audience, bundleVersion: version, routeFile: { _ in file }
            ))
        }
    }

    func testReleaseBindingRejectsAbsentKeysUnreviewedBytesAndMissingBundleResources() throws {
        let inputs = try releaseInputs(Fixture.load())
        for (policy, trust, routes) in [
            (inputs.policy, Data("{}".utf8), inputs.routes),
            (inputs.policy, Data(#"{"schema":"1","policySha256":null,"routeManifestSha256":null,"keys":{}}"#.utf8), inputs.routes),
            (Data("{}".utf8), inputs.trust, inputs.routes),
            (inputs.policy + Data(" ".utf8), inputs.trust, inputs.routes),
            (inputs.policy, inputs.trust, inputs.routes + Data(" ".utf8)),
            (inputs.policy, inputs.trust, Data(repeating: 1, count: 65537))
        ] {
            XCTAssertThrowsError(try MutationAuthorizationReleaseBinding.verifier(
                policyData: policy, trustData: trust, routeManifestData: routes,
                applicationId: "jp.co.soramitsu.fearlesswallet", bundleVersion: "2026.8.34",
                routeFile: { _ in inputs.routeFile }
            ))
        }
        XCTAssertThrowsError(try MutationAuthorizationReleaseBinding.makeAuthority(bundle: Bundle(for: Self.self)))
    }

    func testReleaseBindingCannotSubstituteAnUnrelatedFileEvenWithMatchingHashPins() throws {
        for name in ["unrelated.json", "../mutation_route_inventory.json", "Mutation_route_inventory.json"] {
            let inputs = try releaseInputs(Fixture.load(), routeName: name)
            var reads = 0
            XCTAssertThrowsError(try MutationAuthorizationReleaseBinding.verifier(
                policyData: inputs.policy, trustData: inputs.trust, routeManifestData: inputs.routes,
                applicationId: "jp.co.soramitsu.fearlesswallet", bundleVersion: "2026.8.34",
                routeFile: { _ in reads += 1; return inputs.routeFile }
            ))
            XCTAssertEqual(reads, 0)
        }
    }

    private func releaseInputs(_ fixture: Fixture, routeName: String = "mutation_route_inventory.json") throws -> (policy: Data, trust: Data, routes: Data, routeFile: Data) {
        let policy = Data(#"{"schema":"1","audience":"jp.co.soramitsu.fearlesswallet","environment":"production","appVersion":"20260834","bundleVersion":"2026.8.34","capabilities":{"demeter":false,"polkamarkt":false,"polkaswap":false,"polkaswapBridge":false,"xcm":true}}"#.utf8)
        let file = Data(#"{"testOnly":true,"routes":[]}"#.utf8)
        let routes = try JSONSerialization.data(withJSONObject: [
            "schema": "1", "files": [routeName: MutationAuthorizationVerifier.sha256(file)]
        ], options: [.sortedKeys])
        let trust = try JSONSerialization.data(withJSONObject: [
            "schema": "1", "policySha256": MutationAuthorizationVerifier.sha256(policy),
            "routeManifestSha256": MutationAuthorizationVerifier.sha256(routes),
            "keys": [fixture.keyId: fixture.publicKeyHex]
        ], options: [.sortedKeys])
        return (policy, trust, routes, file)
    }
}

private struct Fixture: Decodable {
    struct Vector: Decodable { let name: String; let token: String; let expectedValid: Bool }
    let testOnly: Bool
    let keyId: String
    let publicKeyHex: String
    let vectors: [Vector]

    static func load() throws -> Fixture {
        let url = try XCTUnwrap(Bundle(for: MutationAuthorizationTests.self).url(
            forResource: "MutationAuthorizationVectors", withExtension: "json"
        ))
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }

    func verifier(
        audience: String = "jp.co.soramitsu.fearless", version: Int64 = 230,
        policy: String = String(repeating: "1", count: 64),
        routes: String = String(repeating: "2", count: 64),
        compiled: Set<MutationCapability> = [.xcm], keys: [String: Data]? = nil
    ) throws -> MutationAuthorizationVerifier {
        MutationAuthorizationVerifier(
            context: MutationAuthorizationContext(
                audience: audience,
                appVersion: version,
                policySha256: policy,
                routeManifestSha256: routes,
                compiledCapabilities: compiled
            ),
            trustedKeys: try keys ?? [keyId: hex(publicKeyHex)]
        )
    }

    func token(_ name: String) throws -> String { try XCTUnwrap(vectors.first { $0.name == name }).token }

    func payload(_ name: String) throws -> String {
        let segment = try token(name).split(separator: ".")[2]
        var value = segment.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        value += String(repeating: "=", count: (4 - value.count % 4) % 4)
        return try XCTUnwrap(String(data: XCTUnwrap(Data(base64Encoded: value)), encoding: .utf8))
    }

    func sign(_ payload: String, domain: String = "FearlessWallet-MutationAuthorization-v1\n") throws -> String {
        // PUBLIC RFC8032 TEST1 seed only. Never an operator or production key.
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation:
            hex("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"))
        let signature = try key.signature(for: Data((domain + keyId + "\n" + payload).utf8))
        return "FWMA1.\(keyId).\(base64URL(Data(payload.utf8))).\(base64URL(signature))"
    }

    private func hex(_ value: String) throws -> Data {
        try Data(stride(from: 0, to: value.count, by: 2).map {
            let start = value.index(value.startIndex, offsetBy: $0)
            return try XCTUnwrap(UInt8(value[start ..< value.index(start, offsetBy: 2)], radix: 16))
        })
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

private final class TestClock {
    var wall: Int64 = 1_800_000_010
    var continuous: Double = 100
    func read() -> MutationAuthorizationClock {
        MutationAuthorizationClock(wallSeconds: wall, continuousSeconds: continuous)
    }
}

private final class TestStore: MutationAuthorizationHighWaterStoring {
    var value: MutationAuthorizationHighWater?
    var failLoad = false
    var failSave = false
    var commitBeforeError = false
    var afterSave: (() -> Void)?
    func load() throws -> MutationAuthorizationHighWater? {
        if failLoad { throw MutationAuthorizationError.persistenceUnavailable }
        return value
    }

    func save(_ value: MutationAuthorizationHighWater) throws {
        if !failSave || commitBeforeError { self.value = value }
        if failSave { throw MutationAuthorizationError.persistenceUnavailable }
        afterSave?()
    }
}

private final class Harness {
    let fixture: Fixture
    let store = TestStore()
    let clock = TestClock()
    var authority: MutationAuthorizationAuthority
    init() throws {
        fixture = try Fixture.load()
        authority = try MutationAuthorizationAuthority(verifier: fixture.verifier(), store: store, clock: clock.read)
    }

    func enable() throws { try authority.acceptFreshResponse(fixture.token("valid_xcm_enabled")) }
    func newAuthority(compiled: Set<MutationCapability> = [.xcm]) throws -> MutationAuthorizationAuthority {
        try MutationAuthorizationAuthority(verifier: fixture.verifier(compiled: compiled), store: store, clock: clock.read)
    }
}

private final class KeychainMock {
    var data: Data?
    var readError: OSStatus?
    var writeError: OSStatus?
    var adds = 0
    var lastQuery: [String: Any]?
    var lastAttributes: [String: Any]?
    func store() throws -> MutationAuthorizationKeychainStore {
        try MutationAuthorizationKeychainStore(audience: "test.fearless", read: { query, result in
            self.lastQuery = query as? [String: Any]
            if let error = self.readError { return error }
            guard let data = self.data else { return errSecItemNotFound }
            result?.pointee = data as CFData
            return errSecSuccess
        }, update: { _, attributes in
            if let error = self.writeError { return error }
            guard self.data != nil else { return errSecItemNotFound }
            self.lastAttributes = attributes as? [String: Any]
            self.data = self.lastAttributes?[kSecValueData as String] as? Data
            return errSecSuccess
        }, add: { attributes, _ in
            if let error = self.writeError { return error }
            self.adds += 1
            self.lastAttributes = attributes as? [String: Any]
            self.data = self.lastAttributes?[kSecValueData as String] as? Data
            return errSecSuccess
        })
    }
}

extension MutationAuthorizationTests {
    func testOperationRequiresKeySignatureBindingAndOnlyOneHandoff() throws {
        let harness = try Harness()
        try harness.enable()
        let operation = try harness.operation(intent: intent)
        XCTAssertThrowsError(try operation.authorize { XCTFail("Unbound send") })
        XCTAssertThrowsError(try operation.withSignature { XCTFail("Signature before key") })
        XCTAssertEqual(try operation.withKeyAccess { 42 }, 42)
        XCTAssertThrowsError(try operation.withKeyAccess { XCTFail("Repeated key read") })
        XCTAssertEqual(try operation.withSignature { Data([1]) }, Data([1]))
        XCTAssertThrowsError(try operation.withSignature { XCTFail("Repeated signature") })
        XCTAssertThrowsError(try operation.bindSubmission(extrinsic: Data(), method: "author_submitExtrinsic"))
        XCTAssertThrowsError(try operation.bindSubmission(extrinsic: Data([1]), method: "state_getStorage"))
        try operation.bindSubmission(extrinsic: Data([1]), method: "author_submitExtrinsic")
        XCTAssertThrowsError(try operation.bindSubmission(extrinsic: Data([2]), method: "author_submitExtrinsic"))
        var sent = 0
        try operation.authorize { sent += 1 }
        XCTAssertThrowsError(try operation.authorize { sent += 1 })
        XCTAssertEqual(sent, 1)
    }

    func testOperationRechecksAuthorityAfterKeyPreparationAndBeforeWriter() throws {
        for stop in ["key", "signature", "binding", "writer"] {
            let harness = try Harness()
            try harness.enable()
            let operation = try harness.operation(intent: intent)
            var effects: [String] = []
            if stop == "key" { harness.authority.refreshFailed() }
            do {
                try operation.withKeyAccess { effects.append("key") }
                if stop == "signature" { harness.clock.continuous += 900 }
                try operation.withSignature { effects.append("signature") }
                if stop == "binding" { harness.authority.refreshFailed() }
                try operation.bindSubmission(extrinsic: Data([1]), method: "author_submitAndWatchExtrinsic")
                if stop == "writer" { harness.clock.continuous += 900 }
                try operation.authorize { effects.append("writer") }
                XCTFail("Expected rejection at \(stop)")
            } catch { XCTAssertTrue(error is MutationAuthorizationError) }
            XCTAssertEqual(effects, stop == "key" ? [] : stop == "signature" ? ["key"] : ["key", "signature"])
        }
    }

    func testOperationSamplesClockAfterSlowContextValidation() throws {
        let harness = try Harness()
        try harness.enable()
        let operation = try harness.operation(intent: intent) { harness.clock.continuous += 900 }
        XCTAssertThrowsError(try operation.withKeyAccess { XCTFail("Expired after context read") })
    }

    func testChangedContextCannotReadKeySignOrSend() throws {
        for stop in 0...7 {
            let harness = try Harness()
            try harness.enable()
            var validations = 0
            let operation = try harness.operation(intent: intent) {
                defer { validations += 1 }
                if validations == stop { throw MutationAuthorizationError.changedIntent }
            }
            var effects = 0
            XCTAssertThrowsError(try {
                try operation.withKeyAccess { effects += 1 }
                try operation.withSignature { effects += 1 }
                try operation.bindSubmission(extrinsic: Data([1]), method: "author_submitExtrinsic")
                try operation.authorize { effects += 1 }
            }())
            XCTAssertEqual(effects, min(stop / 2, 2))
        }
    }

    func testFailedKeyOrSignaturePermanentlyConsumesOperation() throws {
        for failKey in [true, false] {
            let operation = try MutationOperationAuthorization(intentSha256: intent, validateContext: {}) { try $0() }
            if failKey {
                XCTAssertThrowsError(try operation.withKeyAccess { throw MutationAuthorizationError.denied })
            } else {
                try operation.withKeyAccess {}
                XCTAssertThrowsError(try operation.withSignature { throw MutationAuthorizationError.denied })
            }
            XCTAssertThrowsError(try operation.withKeyAccess { XCTFail("Key retry") })
            XCTAssertThrowsError(try operation.withSignature { XCTFail("Signature retry") })
            XCTAssertThrowsError(try operation.authorize { XCTFail("Send after error") })
        }
    }

    func testUnknownTransportOutcomeCannotRetry() throws {
        let harness = try Harness()
        try harness.enable()
        let operation = try harness.operation(intent: intent)
        try operation.withKeyAccess {}
        try operation.withSignature {}
        try operation.bindSubmission(extrinsic: Data([1]), method: "author_submitExtrinsic")
        var sends = 0
        XCTAssertThrowsError(try operation.authorize {
            sends += 1
            throw MutationAuthorizationError.denied
        })
        XCTAssertThrowsError(try operation.authorize { sends += 1 })
        XCTAssertEqual(sends, 1)
    }

    func testOperationReentrancyDeniesWithoutBlocking() throws {
        let operation = try MutationOperationAuthorization(intentSha256: intent, validateContext: {}) { try $0() }
        try operation.withKeyAccess {
            XCTAssertThrowsError(try operation.withSignature { XCTFail("Reentrant signing") })
        }
        try operation.withSignature {}
    }

    func testBoundaryThatDoesNotInvokeActionCannotClaimSuccess() throws {
        let operation = try MutationOperationAuthorization(intentSha256: intent, validateContext: {}) { _ in }
        XCTAssertThrowsError(try operation.withKeyAccess { XCTFail("No boundary") })
    }

    func testIntentDigestBindsOrderedFieldsWithoutDelimiterAmbiguity() throws {
        XCTAssertNotEqual(try MutationIntentDigest.make(["ab", "c"]), try MutationIntentDigest.make(["a", "bc"]))
        XCTAssertNotEqual(try MutationIntentDigest.make(["a", "b"]), try MutationIntentDigest.make(["b", "a"]))
        XCTAssertNotEqual(try MutationIntentDigest.make(["a"]), try MutationIntentDigest.make(["a", ""]))
        XCTAssertEqual(try MutationIntentDigest.make(["xcm", "wallet", "route", "10"]), try MutationIntentDigest.make(["xcm", "wallet", "route", "10"]))
        XCTAssertThrowsError(try MutationIntentDigest.make([]))
        XCTAssertThrowsError(try MutationIntentDigest.make(Array(repeating: "a", count: 65)))
        XCTAssertThrowsError(try MutationIntentDigest.make([String(repeating: "a", count: 16_385)]))
        XCTAssertThrowsError(try MutationOperationAuthorization(intentSha256: "wrong", validateContext: {}) { try $0() })
    }

    func testFinalContextTryReadRejectsActiveAndQueuedRegistryWriters() throws {
        let lock = fearless.ReaderWriterLock()
        var value = 1
        XCTAssertEqual(lock.tryConcurrentlyRead { value }, 1)
        let entered = DispatchSemaphore(value: 0)
        let finish = DispatchSemaphore(value: 0)
        lock.exclusivelyWrite {
            entered.signal()
            XCTAssertEqual(finish.wait(timeout: .now() + 3), .success)
            value = 2
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        lock.exclusivelyWrite { value = 3 }
        XCTAssertNil(lock.tryConcurrentlyRead { XCTFail("Must not read changing chain"); return value })
        finish.signal()
        XCTAssertEqual(lock.concurrentlyRead { value }, 3)
        XCTAssertEqual(lock.tryConcurrentlyRead { value }, 3)
    }

    func testQueuedWriterCannotRunDuringFinalContextTryRead() throws {
        let lock = fearless.ReaderWriterLock()
        let queued = DispatchSemaphore(value: 0)
        let finished = expectation(description: "writer finished")
        var value = 1
        let result = lock.tryConcurrentlyRead { () -> Int in
            DispatchQueue.global().async {
                queued.signal()
                lock.exclusivelyWrite { value = 2; finished.fulfill() }
            }
            XCTAssertEqual(queued.wait(timeout: .now() + 3), .success)
            return value
        }
        XCTAssertEqual(result, 1)
        wait(for: [finished], timeout: 3)
        XCTAssertEqual(lock.concurrentlyRead { value }, 2)
    }
}

private extension Harness {
    func operation(intent: String, validateContext: @escaping () throws -> Void = {}) throws -> MutationOperationAuthorization {
        let lease = try authority.lease(for: .xcm, intentSha256: intent)
        return try MutationOperationAuthorization(intentSha256: intent, validateContext: validateContext) { action in
            try self.authority.withAuthorizedContext(lease, intentSha256: intent, validateContext: validateContext, action: action)
        }
    }
}

extension MutationAuthorizationTests {
    func testSubmitAndWatchCarryFinalAuthorizationAndDisableReconnectReplay() throws {
        for watch in [false, true] {
            let harness = try Harness()
            try harness.enable()
            let authorization = try harness.operation(intent: intent)
            let signer = MutationFactorySigner(authorization: authorization)
            let factory = mutationFactory()
            let operations: [Operation]
            if watch { operations = factory.submitAndWatch({ $0 }, signer: signer).allOperations }
            else { operations = factory.submit({ builder, _ in builder }, signer: signer, numberOfExtrinsics: 1).allOperations }
            let method = watch ? "author_submitAndWatchExtrinsic" : "author_submitExtrinsic"
            let submission = try XCTUnwrap(operations.compactMap { $0 as? JSONRPCListOperation<String> }.first { $0.method == method })
            XCTAssertFalse(submission.requestOptions.resendOnReconnect)
            let transportGuard = try XCTUnwrap(submission.requestOptions.writeAuthorization)
            XCTAssertThrowsError(try transportGuard.authorize { XCTFail("Send before signing") })
            try authorization.withKeyAccess {}
            try authorization.withSignature {}
            let built = try XCTUnwrap(submission.dependencies.first as? BaseOperation<[Data]>)
            built.result = .success([Data([1, 2, 3])])
            submission.configurationBlock?()
            XCTAssertNil(submission.result)
            XCTAssertEqual(submission.parameters, ["0x010203"])
            // Revocation after async construction must still stop the exact
            // guard carried to the SDK's final transport boundary.
            harness.authority.refreshFailed()
            XCTAssertThrowsError(try transportGuard.authorize { XCTFail("Revoked send") })
        }
    }

    func testGuardedBatchIsRejectedBeforeConstructingTransactions() throws {
        let harness = try Harness()
        try harness.enable()
        let signer = MutationFactorySigner(authorization: try harness.operation(intent: intent))
        let wrapper = mutationFactory().submit({ _, _ in
            XCTFail("Guarded batch constructed")
            throw MutationAuthorizationError.changedIntent
        }, signer: signer, numberOfExtrinsics: 2)
        XCTAssertEqual(wrapper.allOperations.count, 1)
        wrapper.targetOperation.start()
        XCTAssertThrowsError(try XCTUnwrap(wrapper.targetOperation.result).get())
    }

    func testLegacySubmissionRetainsExistingRpcOptions() throws {
        let wrapper = mutationFactory().submit({ builder, _ in builder },
                                               signer: MutationFactorySigner(authorization: nil), numberOfExtrinsics: 1)
        let submission = try XCTUnwrap(wrapper.allOperations.compactMap { $0 as? JSONRPCListOperation<String> }
            .first { $0.method == "author_submitExtrinsic" })
        XCTAssertNil(submission.requestOptions.writeAuthorization)
        XCTAssertTrue(submission.requestOptions.resendOnReconnect)
    }

    private func mutationFactory() -> ExtrinsicOperationFactory {
        ExtrinsicOperationFactory(accountId: Data(repeating: 1, count: 32), chainFormat: .substrate(42),
                                  cryptoType: .sr25519, runtimeRegistry: MutationFactoryRuntime(), engine: MockConnection())
    }
}

private final class MutationFactorySigner: SigningWrapperProtocol {
    let mutationAuthorization: MutationOperationAuthorization?
    init(authorization: MutationOperationAuthorization?) { mutationAuthorization = authorization }
    func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        XCTFail("These operation-wiring tests must not execute a native signer")
        throw MutationAuthorizationError.denied
    }
}

private final class MutationFactoryRuntime: RuntimeCodingServiceProtocol {
    var snapshot: RuntimeSnapshot? { nil }
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> { BaseOperation() }
    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol { throw MutationAuthorizationError.denied }
}

extension MutationAuthorizationTests {
    func testContextChangeDuringDurableAuthorityCheckStopsEveryEffect() throws {
        for stop in 0...3 {
            let harness = try Harness()
            try harness.enable()
            var contextMatches = true
            let operation = try harness.operation(intent: intent) {
                guard contextMatches else { throw MutationAuthorizationError.changedIntent }
            }
            let steps: [() throws -> Void] = [
                { try operation.withKeyAccess {} },
                { try operation.withSignature {} },
                { try operation.bindSubmission(extrinsic: Data([1]), method: "author_submitExtrinsic") },
                { try operation.authorize {} }
            ]
            for index in 0..<stop { try steps[index]() }
            harness.clock.wall += 1
            harness.store.afterSave = { contextMatches = false }
            XCTAssertThrowsError(try steps[stop]())
            XCTAssertFalse(contextMatches, "Persistence must race between preflight and final context")
        }
    }

    func testContextCrossingClockSecondIsRevalidatedAfterPersistence() throws {
        let harness = try Harness()
        try harness.enable()
        let lease = try harness.authority.lease(for: .xcm, intentSha256: intent)
        var validations = 0
        var effects = 0
        try harness.authority.withAuthorizedContext(lease, intentSha256: intent, validateContext: {
            validations += 1
            if validations == 1 { harness.clock.wall += 1 }
        }, action: { effects += 1 })
        XCTAssertEqual(validations, 2)
        XCTAssertEqual(effects, 1)
        XCTAssertEqual(harness.store.value?.maximumWallSeconds, harness.clock.wall)
    }

    func testContinuouslyChangingOrExpiredContextNeverRunsEffect() throws {
        for expiry in [false, true] {
            let harness = try Harness()
            try harness.enable()
            let lease = try harness.authority.lease(for: .xcm, intentSha256: intent)
            var validations = 0
            XCTAssertThrowsError(try harness.authority.withAuthorizedContext(lease, intentSha256: intent,
                validateContext: {
                    validations += 1
                    if expiry { harness.clock.continuous += 900 }
                    else { harness.clock.wall += 1 }
                }, action: { XCTFail("Effect after changed time") }))
            XCTAssertEqual(validations, expiry ? 1 : 3)
        }
    }
}
