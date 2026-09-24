import CryptoKit
@testable import fearless
import Foundation
import XCTest

final class IOSReceiveKeychainProjectionTests: XCTestCase {
    private typealias Codec = IOSPortableWalletSemanticMaterial
    private typealias FieldID = IOSPortableWalletSemanticMaterial.FieldID
    private typealias Journal = IOSPortableWalletReceiveJournalRecord
    private typealias Projection = IOSReceiveKeychainProjection

    private let destinationID = "A1A2A3A4-1111-4111-8111-111111111111"
    private let transactionID = "B1B2B3B4-2222-4222-8222-222222222222"

    func testProjectsExactReleasedIOSKeysBoundToJournal() throws {
        var snapshot = wallet(slots: [
            evmRoot(),
            source("0000", role: 2, binding: 3, bytes: [0xA1, 0xB2]),
            source("0001", role: 4, binding: 1, bytes: [0xC3])
        ])
        defer { snapshot.clearSecrets() }
        let encoded = try Codec.encode(snapshot)
        let secretTag = KeystoreTagV2.ethereumSecretKeyTagForMetaId(destinationID)
        let entropyTag = KeystoreTagV2.entropyTagForMetaId(destinationID)
        let record = journal(encoded, wallet: snapshot.wallets[0], keys: [
            (secretTag, Data([0xA1, 0xB2])), (entropyTag, Data([0xC3]))
        ])

        var projected = try Projection.project(semantic: encoded, journal: record)
        defer { for index in projected.indices {
            projected[index].clearSecret()
        } }
        XCTAssertEqual(projected.map(\.tag), [secretTag, entropyTag].sorted())
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: projected.map { ($0.tag, $0.value) }), [
            secretTag: Data([0xA1, 0xB2]), entropyTag: Data([0xC3])
        ])
        XCTAssertFalse(String(reflecting: projected[0]).contains(secretTag))
        XCTAssertFalse(String(describing: projected[0]).contains("A1"))
    }

    func testRejectsMissingOrChangedKeyAndAlteredSemanticCohort() throws {
        var snapshot = wallet(slots: [evmRoot(secret: [0xA1]), source("0000", role: 2, binding: 3, bytes: [0xA1])])
        defer { snapshot.clearSecrets() }
        let encoded = try Codec.encode(snapshot)
        let tag = KeystoreTagV2.ethereumSecretKeyTagForMetaId(destinationID)
        let correct = journal(encoded, wallet: snapshot.wallets[0], keys: [(tag, Data([0xA1]))])
        let missing = journal(encoded, wallet: snapshot.wallets[0], keys: [])
        let changed = journal(encoded, wallet: snapshot.wallets[0], keys: [(tag, Data([0xA2]))])
        XCTAssertThrowsError(try Projection.project(semantic: encoded, journal: missing))
        XCTAssertThrowsError(try Projection.project(semantic: encoded, journal: changed))

        snapshot.wallets[0].slots[1].fields[5].value = [0xA2]
        XCTAssertThrowsError(try Projection.project(semantic: Codec.encode(snapshot), journal: correct))
    }

    func testRejectsDuplicateDestinationTagBeforeAnyWrite() throws {
        var snapshot = wallet(slots: [
            evmRoot(secret: [0xA1]),
            source("0000", role: 2, binding: 3, bytes: [0xA1]),
            source("0001", role: 2, binding: 3, bytes: [0xA1])
        ])
        defer { snapshot.clearSecrets() }
        let encoded = try Codec.encode(snapshot)
        let tag = KeystoreTagV2.ethereumSecretKeyTagForMetaId(destinationID)
        let record = journal(encoded, wallet: snapshot.wallets[0], keys: [(tag, Data([0xA1]))])
        XCTAssertThrowsError(try Projection.project(semantic: encoded, journal: record)) { error in
            XCTAssertEqual(error as? Projection.ProjectionError, .duplicateDestinationTag)
        }
    }

    func testRejectsConflictingRootSigningKeyEvenWithMatchingJournalDigests() throws {
        var snapshot = wallet(slots: [
            evmRoot(), source("0000", role: 2, binding: 3, bytes: [0xA1])
        ])
        defer { snapshot.clearSecrets() }
        let encoded = try Codec.encode(snapshot)
        let tag = KeystoreTagV2.ethereumSecretKeyTagForMetaId(destinationID)
        let record = journal(encoded, wallet: snapshot.wallets[0], keys: [(tag, Data([0xA1]))])
        XCTAssertThrowsError(try Projection.project(semantic: encoded, journal: record)) { error in
            XCTAssertEqual(error as? Projection.ProjectionError, .invalidSource)
        }

        snapshot.wallets[0].slots[1] = source("0000", role: 2, binding: 1, bytes: [0xA1])
        let walletWide = try Codec.encode(snapshot)
        let walletWideRecord = journal(walletWide, wallet: snapshot.wallets[0], keys: [(tag, Data([0xA1]))])
        XCTAssertThrowsError(try Projection.project(semantic: walletWide, journal: walletWideRecord)) { error in
            XCTAssertEqual(error as? Projection.ProjectionError, .invalidSource)
        }
    }

    func testRejectsMissingRootSignerAndConflictingWalletEntropy() throws {
        var missing = wallet(slots: [evmRoot()])
        defer { missing.clearSecrets() }
        let missingBytes = try Codec.encode(missing)
        let missingRecord = journal(missingBytes, wallet: missing.wallets[0], keys: [])
        XCTAssertThrowsError(try Projection.project(semantic: missingBytes, journal: missingRecord)) { error in
            XCTAssertEqual(error as? Projection.ProjectionError, .missingRequiredKey)
        }

        var root = evmRoot()
        root.fields.append(field(FieldID.entropy, [0xC3]))
        root.fields.sort { $0.id < $1.id }
        var conflicting = wallet(slots: [
            root,
            source("0000", role: 2, binding: 3, bytes: [0xA1, 0xB2]),
            source("0001", role: 4, binding: 1, bytes: [0xD4])
        ])
        defer { conflicting.clearSecrets() }
        let encoded = try Codec.encode(conflicting)
        let secretTag = KeystoreTagV2.ethereumSecretKeyTagForMetaId(destinationID)
        let entropyTag = KeystoreTagV2.entropyTagForMetaId(destinationID)
        let record = journal(encoded, wallet: conflicting.wallets[0], keys: [
            (secretTag, Data([0xA1, 0xB2])), (entropyTag, Data([0xD4]))
        ])
        XCTAssertThrowsError(try Projection.project(semantic: encoded, journal: record)) { error in
            XCTAssertEqual(error as? Projection.ProjectionError, .invalidSource)
        }
    }

    func testRejectsUnmappedAndroidSourceAndOversizedIOSSource() throws {
        var snapshot = wallet(slots: [
            evmRoot(),
            source("0000", role: 12, binding: 3, platform: 1, format: 4, bytes: [0xA1])
        ])
        defer { snapshot.clearSecrets() }
        let encoded = try Codec.encode(snapshot)
        let record = journal(encoded, wallet: snapshot.wallets[0], keys: [])
        XCTAssertThrowsError(try Projection.project(semantic: encoded, journal: record)) { error in
            XCTAssertEqual(error as? Projection.ProjectionError, .unsupportedSource)
        }

        snapshot.wallets[0].slots[1] = source("0000", role: 2, binding: 3, bytes: [UInt8](repeating: 7, count: 4097))
        let oversized = try Codec.encode(snapshot)
        let oversizedRecord = journal(oversized, wallet: snapshot.wallets[0], keys: [])
        XCTAssertThrowsError(try Projection.project(semantic: oversized, journal: oversizedRecord)) { error in
            XCTAssertEqual(error as? Projection.ProjectionError, .invalidSource)
        }
    }

    func testChainBoundSourceUsesScopedOriginalKeyTag() throws {
        let accountID = Data(repeating: 0xAB, count: 20)
        let chain = Codec.Slot(role: Codec.Role.chainAccount, key: "chain-a", fields: [
            field(FieldID.publicKey, [1]), field(FieldID.privateKey, [0xF1]),
            field(FieldID.accountIDOrAddress, Array(accountID)), field(FieldID.cryptoType, [1]),
            field(FieldID.chainName, []), field(FieldID.initializedOrFavorite, [1]),
            field(FieldID.sourceRecipe, [0])
        ])
        var snapshot = wallet(slots: [
            evmRoot(), chain,
            source("0000", role: 2, binding: 3, bytes: [0xA1, 0xB2]),
            source("0001", role: 1, binding: 5, bytes: [0xF1], chainID: "chain-a", accountID: accountID)
        ])
        defer { snapshot.clearSecrets() }
        let encoded = try Codec.encode(snapshot)
        let tag = KeystoreTagV2.substrateSecretKeyTagForMetaId(destinationID, accountId: accountID)
        let rootTag = KeystoreTagV2.ethereumSecretKeyTagForMetaId(destinationID)
        let record = journal(encoded, wallet: snapshot.wallets[0], keys: [
            (rootTag, Data([0xA1, 0xB2])), (tag, Data([0xF1]))
        ])
        var projected = try Projection.project(semantic: encoded, journal: record)
        defer { for index in projected.indices {
            projected[index].clearSecret()
        } }
        XCTAssertEqual(projected.map(\.tag), [rootTag, tag].sorted())
        XCTAssertEqual(projected.first(where: { $0.tag == tag })?.value, Data([0xF1]))
    }

    private func wallet(slots: [Codec.Slot]) -> Codec.Snapshot {
        Codec.Snapshot(selectedIndex: 0, wallets: [
            .init(
                portableID: [UInt8](repeating: 0x33, count: 16),
                sourcePosition: 1,
                initialized: true,
                name: "Wallet",
                metadata: [],
                slots: slots
            )
        ])
    }

    private func evmRoot(secret: [UInt8] = [0xA1, 0xB2]) -> Codec.Slot {
        Codec.Slot(role: Codec.Role.evmRoot, key: "", fields: [
            field(FieldID.publicKey, [1]), field(FieldID.privateKey, secret),
            field(FieldID.accountIDOrAddress, [2]), field(FieldID.sourceRecipe, [0])
        ])
    }

    private func source(
        _ key: String, role: UInt8, binding: UInt8, platform: UInt8 = 2,
        format: UInt8 = 1, bytes: [UInt8], chainID: String? = nil, accountID: Data? = nil
    ) -> Codec.Slot {
        var fields = [
            field(FieldID.sourceRecipe, [0]), field(FieldID.sourcePlatform, [platform]),
            field(FieldID.sourceSlotRole, [role]), field(FieldID.bindingKind, [binding]),
            field(FieldID.sourceFormat, [format]), field(FieldID.sourceBytes, bytes)
        ]
        if let chainID, let accountID {
            fields.append(field(FieldID.bindingChainID, Array(chainID.utf8)))
            fields.append(field(FieldID.bindingAccountID, Array(accountID)))
        }
        return Codec.Slot(
            role: Codec.Role.auxiliarySource,
            key: key,
            fields: fields.sorted { $0.id < $1.id }
        )
    }

    private func field(_ id: UInt8, _ value: [UInt8]) -> Codec.Field {
        Codec.Field(id: id, value: value)
    }

    private func journal(
        _ encoded: Data, wallet: Codec.Wallet, keys: [(String, Data)]
    ) -> Journal.Record {
        Journal.Record(
            schemaVersion: Journal.schemaVersion, transactionID: transactionID,
            semanticSHA256: Data(SHA256.hash(data: encoded)), selectedIndex: 0,
            wallets: [.init(metaID: destinationID, portableID: Data(wallet.portableID))],
            keys: keys.map { Journal.KeyProof(tag: $0.0, sha256: Data(SHA256.hash(data: $0.1))) }
                .sorted { $0.tag < $1.tag },
            phase: .staging
        )
    }
}
