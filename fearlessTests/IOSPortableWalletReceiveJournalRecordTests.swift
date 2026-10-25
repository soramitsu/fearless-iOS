import CryptoKit
@testable import fearless
import Foundation
import XCTest

final class IOSReceiveJournalRecordTests: XCTestCase {
    private typealias Journal = IOSPortableWalletReceiveJournalRecord
    private typealias Codec = IOSPortableWalletSemanticMaterial
    private let firstID = "11111111-1111-4111-a111-111111111111"
    private let secondID = "22222222-2222-4222-8222-222222222222"

    func testCanonicalRecordRoundTripsWithoutExposingWalletMetadataInDescriptions() throws {
        let record = fixture()
        let encoded = try Journal.encode(record)
        XCTAssertEqual(try Journal.decode(encoded), record)
        XCTAssertFalse(String(describing: record).contains(firstID))
        XCTAssertFalse(String(reflecting: record).contains(firstID))
        XCTAssertFalse(String(reflecting: record.wallets[0]).contains(firstID))
        XCTAssertFalse(String(reflecting: record.keys[0]).contains(firstID))
    }

    func testRejectsNoncanonicalWireAndUnsupportedSchema() throws {
        let record = fixture()
        var encoded = try Journal.encode(record)
        encoded.append(0x20)
        XCTAssertThrowsError(try Journal.decode(encoded))
        XCTAssertThrowsError(try Journal.encode(replacing(record, schemaVersion: 2)))
        XCTAssertThrowsError(try Journal.encode(replacing(record, transactionID: "not-a-uuid")))
    }

    func testAcceptsFoundationUppercaseDestinationUUIDs() throws {
        let original = fixture()
        let uppercaseWallets = original.wallets.map {
            Journal.WalletBinding(metaID: $0.metaID.uppercased(), portableID: $0.portableID)
        }
        let uppercaseKeys = original.keys.map {
            Journal.KeyProof(
                tag: String($0.tag.prefix(36)).uppercased() + String($0.tag.dropFirst(36)),
                sha256: $0.sha256
            )
        }
        let record = Journal.Record(
            schemaVersion: original.schemaVersion, transactionID: original.transactionID.uppercased(),
            semanticSHA256: original.semanticSHA256, selectedIndex: original.selectedIndex,
            wallets: uppercaseWallets, keys: uppercaseKeys, phase: original.phase
        )
        XCTAssertEqual(try Journal.decode(Journal.encode(record)), record)
    }

    func testRejectsDuplicateDestinationsAndForeignOrUnsortedKeyTags() throws {
        let record = fixture()
        let duplicateWallet = Journal.Record(
            schemaVersion: record.schemaVersion, transactionID: record.transactionID,
            semanticSHA256: record.semanticSHA256, selectedIndex: 0,
            wallets: [record.wallets[0], record.wallets[0]], keys: record.keys,
            phase: record.phase
        )
        XCTAssertThrowsError(try Journal.encode(duplicateWallet))

        let caseChangedDuplicate = Journal.Record(
            schemaVersion: record.schemaVersion, transactionID: record.transactionID,
            semanticSHA256: record.semanticSHA256, selectedIndex: 0,
            wallets: [record.wallets[0], .init(
                metaID: firstID.uppercased(), portableID: Data(repeating: 0x33, count: 16)
            )], keys: [], phase: record.phase
        )
        XCTAssertThrowsError(try Journal.encode(caseChangedDuplicate))

        let foreign = Journal.KeyProof(tag: "user-pincode", sha256: Data(repeating: 9, count: 32))
        XCTAssertThrowsError(try Journal.encode(replacing(record, keys: [foreign])))
        XCTAssertThrowsError(try Journal.encode(replacing(record, keys: Array(record.keys.reversed()))))
        XCTAssertThrowsError(try Journal.encode(replacing(record, keys: record.keys + [record.keys[1]])))
    }

    func testInterruptedStagingCanOnlyRemoveMatchingOrphanedKeys() throws {
        let record = fixture()
        let oneObserved = [record.keys[0].tag: record.keys[0].sha256]
        XCTAssertEqual(
            try Journal.recoveryDisposition(
                for: record, database: .available([]), keychain: .available(oneObserved)
            ),
            .verifyStagedKeysForRemoval([record.keys[0].tag])
        )
        XCTAssertEqual(
            try Journal.recoveryDisposition(
                for: record, database: .available([]),
                keychain: .available([record.keys[0].tag: Data(repeating: 0, count: 32)])
            ), .quarantine
        )
        XCTAssertEqual(
            try Journal.recoveryDisposition(
                for: record, database: .unavailable, keychain: .available(oneObserved)
            ), .quarantine
        )
        XCTAssertEqual(
            try Journal.recoveryDisposition(
                for: record, database: .available([]), keychain: .unavailable
            ), .quarantine
        )
    }

    func testCompleteCohortRequiresFurtherReadbackWhilePartialDatabaseQuarantines() throws {
        let record = fixture()
        let keys = Dictionary(uniqueKeysWithValues: record.keys.map { ($0.tag, $0.sha256) })
        XCTAssertEqual(
            try Journal.recoveryDisposition(
                for: record, database: .available([firstID, secondID]),
                keychain: .available(keys)
            ), .verifyCommittedCohort
        )
        XCTAssertEqual(
            try Journal.recoveryDisposition(
                for: record, database: .available([firstID]), keychain: .available(keys)
            ), .quarantine
        )
        XCTAssertEqual(
            try Journal.recoveryDisposition(
                for: replacing(record, phase: .databaseCommitted),
                database: .available([]), keychain: .available(keys)
            ), .quarantine
        )
    }

    func testJournalBindsCanonicalSemanticBytesAndOrderedPortableWalletID() throws {
        let wallet = Codec.Wallet(
            portableID: [UInt8](repeating: 0x11, count: 16), sourcePosition: 0,
            initialized: true, name: "watch", metadata: [], slots: [
                .init(role: Codec.Role.watchIdentity, key: "0000", fields: [
                    .init(id: Codec.FieldID.accountIDOrAddress, value: [9]),
                    .init(id: Codec.FieldID.watchEcosystem, value: [2])
                ])
            ]
        )
        var snapshot = Codec.Snapshot(selectedIndex: 0, wallets: [wallet])
        defer { snapshot.clearSecrets() }
        let semantic = try Codec.encode(snapshot)
        let record = Journal.Record(
            schemaVersion: Journal.schemaVersion,
            transactionID: "33333333-3333-4333-8333-333333333333",
            semanticSHA256: Data(SHA256.hash(data: semantic)), selectedIndex: 0,
            wallets: [.init(metaID: firstID, portableID: Data(wallet.portableID))],
            keys: [], phase: .staging
        )
        XCTAssertNoThrow(try Journal.verifySemanticMaterial(semantic, for: record))
        XCTAssertThrowsError(try Journal.verifySemanticMaterial(semantic + Data([0]), for: record))

        let wrongBinding = Journal.Record(
            schemaVersion: record.schemaVersion, transactionID: record.transactionID,
            semanticSHA256: record.semanticSHA256, selectedIndex: record.selectedIndex,
            wallets: [.init(metaID: firstID, portableID: Data(repeating: 0x22, count: 16))],
            keys: record.keys, phase: record.phase
        )
        XCTAssertThrowsError(try Journal.verifySemanticMaterial(semantic, for: wrongBinding))
    }

    private func fixture() -> Journal.Record {
        Journal.Record(
            schemaVersion: Journal.schemaVersion,
            transactionID: "33333333-3333-4333-8333-333333333333",
            semanticSHA256: Data(repeating: 0xAA, count: 32),
            selectedIndex: 1,
            wallets: [
                Journal.WalletBinding(metaID: firstID, portableID: Data(repeating: 0x11, count: 16)),
                Journal.WalletBinding(metaID: secondID, portableID: Data(repeating: 0x22, count: 16))
            ],
            keys: [
                Journal.KeyProof(tag: firstID + "-substrateSecretKey", sha256: Data(repeating: 1, count: 32)),
                Journal.KeyProof(tag: secondID + "-ethereumSecretKey", sha256: Data(repeating: 2, count: 32))
            ],
            phase: .staging
        )
    }

    private func replacing(
        _ record: Journal.Record,
        schemaVersion: Int? = nil,
        transactionID: String? = nil,
        keys: [Journal.KeyProof]? = nil,
        phase: Journal.Phase? = nil
    ) -> Journal.Record {
        Journal.Record(
            schemaVersion: schemaVersion ?? record.schemaVersion,
            transactionID: transactionID ?? record.transactionID,
            semanticSHA256: record.semanticSHA256,
            selectedIndex: record.selectedIndex,
            wallets: record.wallets,
            keys: keys ?? record.keys,
            phase: phase ?? record.phase
        )
    }
}
