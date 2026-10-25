import CryptoKit
@testable import fearless
import Foundation
import SoraKeystore
import XCTest

final class IOSReceiveInstalledKeyReadbackProofTests: XCTestCase {
    private typealias Codec = IOSPortableWalletSemanticMaterial
    private typealias FieldID = IOSPortableWalletSemanticMaterial.FieldID
    private typealias Journal = IOSPortableWalletReceiveJournalRecord
    private typealias Proof = IOSReceiveInstalledKeyReadbackProof
    private typealias Vacancy = IOSReceiveDestinationVacancyProof

    private struct Fixture {
        let semantic: Data
        let journal: Journal.Record
        let tag: String
    }

    private final class RecordingKeystore: KeystoreProtocol {
        var keys: [String: Data]
        var reads = [String: Int]()
        var checks = [String: Int]()
        var fetchOverride: ((String, Int) throws -> Data)?
        var checkOverride: ((String, Int) throws -> Bool)?
        private(set) var writes = 0

        init(keys: [String: Data]) {
            self.keys = keys
        }

        func fetchKey(for identifier: String) throws -> Data {
            let count = (reads[identifier] ?? 0) + 1
            reads[identifier] = count
            if let fetchOverride {
                return try fetchOverride(identifier, count)
            }
            guard let value = keys[identifier] else { throw KeystoreError.noKeyFound }
            return value
        }

        func checkKey(for identifier: String) throws -> Bool {
            let count = (checks[identifier] ?? 0) + 1
            checks[identifier] = count
            if let checkOverride {
                return try checkOverride(identifier, count)
            }
            return keys[identifier] != nil
        }

        func addKey(_: Data, with _: String) throws {
            writes += 1
            throw KeystoreError.unexpectedFail
        }

        func updateKey(_: Data, with _: String) throws {
            writes += 1
            throw KeystoreError.unexpectedFail
        }

        func deleteKey(for _: String) throws {
            writes += 1
            throw KeystoreError.unexpectedFail
        }
    }

    private let destinationID = "A1A2A3A4-1111-4111-8111-111111111111"
    private let transactionID = "B1B2B3B4-2222-4222-8222-222222222222"

    func testRequiresExactDestinationKeyOnTwoReadPassesWithoutWriting() throws {
        let fixture = try fixture()
        let semantic = fixture.semantic
        let journal = fixture.journal
        let tag = fixture.tag
        let keystore = RecordingKeystore(keys: [tag: Data([0xA1, 0xB2])])

        XCTAssertEqual(try Proof.verify(
            semantic: semantic, journal: journal, keystore: keystore
        ), .init(keys: 1))
        XCTAssertEqual(keystore.reads[tag], 2)
        XCTAssertEqual(keystore.keys[tag], Data([0xA1, 0xB2]))
        XCTAssertEqual(keystore.writes, 0)

        keystore.fetchOverride = { _, count in
            count.isMultiple(of: 2) ? Data([0xA1, 0xB3]) : Data([0xA1, 0xB2])
        }
        keystore.reads.removeAll()
        XCTAssertThrowsError(try Proof.verify(
            semantic: semantic, journal: journal, keystore: keystore
        )) { error in
            XCTAssertEqual(error as? Proof.Failure, .changedKey)
        }
        XCTAssertEqual(keystore.reads[tag], 2)
        XCTAssertEqual(keystore.writes, 0)
    }

    func testRejectsMissingChangedAndUnavailableDestinationKeys() throws {
        let fixture = try fixture()
        let semantic = fixture.semantic
        let journal = fixture.journal
        let tag = fixture.tag
        let keystore = RecordingKeystore(keys: [:])
        XCTAssertThrowsError(try Proof.verify(
            semantic: semantic, journal: journal, keystore: keystore
        )) { error in
            XCTAssertEqual(error as? Proof.Failure, .missingKey)
        }

        keystore.keys[tag] = Data([0xA1, 0xB3])
        XCTAssertThrowsError(try Proof.verify(
            semantic: semantic, journal: journal, keystore: keystore
        )) { error in
            XCTAssertEqual(error as? Proof.Failure, .changedKey)
        }

        keystore.fetchOverride = { _, _ in throw KeystoreError.unexpectedFail }
        XCTAssertThrowsError(try Proof.verify(
            semantic: semantic, journal: journal, keystore: keystore
        )) { error in
            XCTAssertEqual(error as? Proof.Failure, .unavailableKeystore)
        }
        XCTAssertEqual(keystore.writes, 0)
    }

    func testRejectsAlteredJournalBeforeReadingInstalledKeys() throws {
        let fixture = try fixture()
        let semantic = fixture.semantic
        let journal = fixture.journal
        let tag = fixture.tag
        let changed = Journal.Record(
            schemaVersion: journal.schemaVersion,
            transactionID: journal.transactionID,
            semanticSHA256: journal.semanticSHA256,
            selectedIndex: journal.selectedIndex,
            wallets: journal.wallets,
            keys: [.init(tag: tag, sha256: Data(repeating: 0x42, count: 32))],
            phase: journal.phase
        )
        let keystore = RecordingKeystore(keys: [tag: Data([0xA1, 0xB2])])
        XCTAssertThrowsError(try Proof.verify(
            semantic: semantic, journal: changed, keystore: keystore
        )) { error in
            XCTAssertEqual(error as? IOSReceiveKeychainProjection.ProjectionError, .journalMismatch)
        }
        XCTAssertTrue(keystore.reads.isEmpty)
        XCTAssertEqual(keystore.writes, 0)
    }

    func testVacancyRequiresMissingDestinationOnTwoPassesWithoutReadingSecrets() throws {
        let source = try fixture()
        let keystore = RecordingKeystore(keys: [:])

        XCTAssertEqual(try Vacancy.verify(
            semantic: source.semantic, journal: source.journal,
            existingWalletIDs: [], keystore: keystore
        ), .init(wallets: 1, keys: 1))
        XCTAssertEqual(keystore.checks[source.tag], 2)
        XCTAssertTrue(keystore.reads.isEmpty)
        XCTAssertEqual(keystore.writes, 0)
    }

    func testVacancyRejectsWalletIDCollisionBeforeTouchingKeychain() throws {
        let source = try fixture()
        let keystore = RecordingKeystore(keys: [:])

        XCTAssertThrowsError(try Vacancy.verify(
            semantic: source.semantic, journal: source.journal,
            existingWalletIDs: [destinationID.lowercased()], keystore: keystore
        )) { error in
            XCTAssertEqual(error as? Vacancy.Failure, .walletIDOccupied)
        }
        XCTAssertTrue(keystore.checks.isEmpty)
        XCTAssertTrue(keystore.reads.isEmpty)
        XCTAssertEqual(keystore.writes, 0)
    }

    func testVacancyRejectsOccupiedDriftingAndUnavailableKeyTags() throws {
        let source = try fixture()
        let keystore = RecordingKeystore(keys: [source.tag: Data([0xA1, 0xB2])])

        XCTAssertThrowsError(try Vacancy.verify(
            semantic: source.semantic, journal: source.journal,
            existingWalletIDs: [], keystore: keystore
        )) { error in
            XCTAssertEqual(error as? Vacancy.Failure, .keyTagOccupied)
        }
        XCTAssertEqual(keystore.checks[source.tag], 1)

        keystore.checks.removeAll()
        keystore.checkOverride = { _, count in count == 2 }
        XCTAssertThrowsError(try Vacancy.verify(
            semantic: source.semantic, journal: source.journal,
            existingWalletIDs: [], keystore: keystore
        )) { error in
            XCTAssertEqual(error as? Vacancy.Failure, .keyTagOccupied)
        }
        XCTAssertEqual(keystore.checks[source.tag], 2)

        keystore.checks.removeAll()
        keystore.checkOverride = { _, _ in throw KeystoreError.unexpectedFail }
        XCTAssertThrowsError(try Vacancy.verify(
            semantic: source.semantic, journal: source.journal,
            existingWalletIDs: [], keystore: keystore
        )) { error in
            XCTAssertEqual(error as? Vacancy.Failure, .unavailableKeystore)
        }
        XCTAssertTrue(keystore.reads.isEmpty)
        XCTAssertEqual(keystore.writes, 0)
    }

    private func fixture() throws -> Fixture {
        let field: (UInt8, [UInt8]) -> Codec.Field = { .init(id: $0, value: $1) }
        let root = Codec.Slot(role: Codec.Role.evmRoot, key: "", fields: [
            field(FieldID.publicKey, [1]), field(FieldID.privateKey, [0xA1, 0xB2]),
            field(FieldID.accountIDOrAddress, [2]), field(FieldID.sourceRecipe, [0])
        ])
        let source = Codec.Slot(role: Codec.Role.auxiliarySource, key: "0000", fields: [
            field(FieldID.sourceRecipe, [0]), field(FieldID.sourcePlatform, [2]),
            field(FieldID.sourceSlotRole, [2]), field(FieldID.bindingKind, [3]),
            field(FieldID.sourceFormat, [1]), field(FieldID.sourceBytes, [0xA1, 0xB2])
        ])
        var snapshot = Codec.Snapshot(selectedIndex: 0, wallets: [
            .init(
                portableID: [UInt8](repeating: 0x33, count: 16),
                sourcePosition: 1, initialized: true, name: "Wallet",
                metadata: [], slots: [root, source]
            )
        ])
        defer { snapshot.clearSecrets() }
        let encoded = try Codec.encode(snapshot)
        let tag = KeystoreTagV2.ethereumSecretKeyTagForMetaId(destinationID)
        let journal = Journal.Record(
            schemaVersion: Journal.schemaVersion, transactionID: transactionID,
            semanticSHA256: Data(SHA256.hash(data: encoded)), selectedIndex: 0,
            wallets: [.init(metaID: destinationID, portableID: Data(snapshot.wallets[0].portableID))],
            keys: [.init(tag: tag, sha256: Data(SHA256.hash(data: Data([0xA1, 0xB2]))))],
            phase: .staging
        )
        return Fixture(semantic: encoded, journal: journal, tag: tag)
    }
}
