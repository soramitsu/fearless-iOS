import Foundation
import SoraKeystore

/// Read-only proof that every journal-bound destination Keychain item contains
/// exactly the source bytes selected for one receiving cohort. This must run
/// after staging under a future cohort writer boundary; it neither writes a
/// wallet nor establishes Core Data/Keychain atomicity by itself.
enum IOSReceiveInstalledKeyReadbackProof {
    enum Failure: Error, Equatable {
        case missingKey
        case unavailableKeystore
        case changedKey
    }

    struct Counts: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
        let keys: Int

        var description: String {
            "IOSReceiveInstalledKeyReadbackProof.Counts(<redacted>)"
        }

        var debugDescription: String {
            description
        }
    }

    static func verify(
        semantic encoded: Data,
        journal: IOSPortableWalletReceiveJournalRecord.Record,
        keystore: KeystoreProtocol
    ) throws -> Counts {
        var expected = try IOSReceiveKeychainProjection.project(semantic: encoded, journal: journal)
        defer {
            for index in expected.indices {
                expected[index].clearSecret()
            }
        }

        try verifyPass(expected, keystore: keystore)
        try verifyPass(expected, keystore: keystore)
        return Counts(keys: expected.count)
    }

    private static func verifyPass(
        _ expected: [IOSReceiveKeychainProjection.Item],
        keystore: KeystoreProtocol
    ) throws {
        for item in expected {
            var observed: Data
            do {
                observed = try keystore.fetchKey(for: item.tag)
            } catch KeystoreError.noKeyFound {
                throw Failure.missingKey
            } catch {
                throw Failure.unavailableKeystore
            }
            let matches = observed == item.value
            observed.resetBytes(in: 0 ..< observed.count)
            guard matches else { throw Failure.changedKey }
        }
    }
}
