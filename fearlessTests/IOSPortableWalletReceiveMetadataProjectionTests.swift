import CryptoKit
@testable import fearless
import Foundation
import XCTest

final class IOSReceiveMetadataProjectionTests: XCTestCase {
    private typealias Codec = IOSPortableWalletSemanticMaterial
    private typealias MetadataID = IOSPortableWalletSemanticMaterial.MetadataID
    private typealias Projection = IOSPortableReceiveMetadata

    func testProjectsAllNineMetadataValuesWithoutLosingAbsentVersusEmpty() throws {
        let metadata: [Codec.Metadata] = try [
            .init(id: MetadataID.assetKeysOrder, value: stringList(["DOT", "ETH"])),
            .init(id: MetadataID.unusedChainIDs, value: stringList([])),
            .init(id: MetadataID.selectedCurrency, value: Array("JPY".utf8)),
            .init(id: MetadataID.networkManagementFilter, value: Array("all".utf8)),
            .init(id: MetadataID.assetVisibility, value: visibility([("DOT", true), ("ETH", false)])),
            .init(id: MetadataID.favoriteChainIDs, value: stringList(["sora"])),
            .init(id: MetadataID.assetFilterOptions, value: stringList(["hidden", "visible"])),
            .init(id: MetadataID.zeroBalanceAssetsHidden, value: [0]),
            .init(id: MetadataID.canExportEthereumMnemonic, value: [1])
        ]
        let projected = try Projection.decode(metadata)
        XCTAssertEqual(projected.assetKeysOrder, ["DOT", "ETH"])
        XCTAssertEqual(projected.unusedChainIDs, [])
        XCTAssertEqual(projected.selectedCurrencyID, "JPY")
        XCTAssertEqual(projected.networkManagementFilter, "all")
        XCTAssertEqual(projected.assetVisibility, [
            .init(assetID: "DOT", hidden: true), .init(assetID: "ETH", hidden: false)
        ])
        XCTAssertEqual(projected.favoriteChainIDs, ["sora"])
        XCTAssertEqual(projected.assetFilterOptions, ["hidden", "visible"])
        XCTAssertEqual(projected.zeroBalanceAssetsHidden, false)
        XCTAssertEqual(projected.canExportEthereumMnemonic, true)
        XCTAssertFalse(String(describing: projected).contains("JPY"))
        XCTAssertFalse(String(reflecting: projected).contains("JPY"))

        let absent = try Projection.decode([])
        XCTAssertNil(absent.assetKeysOrder)
        XCTAssertNil(absent.unusedChainIDs)
        XCTAssertNil(absent.selectedCurrencyID)
        XCTAssertNil(absent.assetVisibility)
        XCTAssertNil(absent.assetFilterOptions)
        XCTAssertNil(absent.zeroBalanceAssetsHidden)
    }

    func testRejectsDuplicateOutOfOrderAndInvalidMetadata() throws {
        let hidden = Codec.Metadata(id: MetadataID.zeroBalanceAssetsHidden, value: [1])
        XCTAssertThrowsError(try Projection.decode([hidden, hidden]))
        XCTAssertThrowsError(try Projection.decode([
            hidden, .init(id: MetadataID.assetKeysOrder, value: stringList([]))
        ]))
        XCTAssertThrowsError(try Projection.decode([.init(id: MetadataID.zeroBalanceAssetsHidden, value: [2])]))
        XCTAssertThrowsError(try Projection.decode([.init(id: MetadataID.assetKeysOrder, value: [0, 1, 0])]))
        XCTAssertThrowsError(try Projection.decode([.init(id: MetadataID.selectedCurrency, value: [])]))
    }

    func testAndroidDisplayMetadataRoundTripsAndRetainsExplicitEmpty() throws {
        let metadata: [Codec.Metadata] = [
            .init(id: MetadataID.androidSelectedChainID, value: Array("sora".utf8)),
            .init(id: MetadataID.androidChainSelectFilter, value: [])
        ]
        let projected = try Projection.decode(metadata)
        XCTAssertEqual(projected.androidSelectedChainID, "sora")
        XCTAssertEqual(projected.androidChainSelectFilter, "")
        XCTAssertNil(try Projection.decode([]).androidSelectedChainID)
        XCTAssertNil(try Projection.decode([]).androidChainSelectFilter)

        let watch = Codec.Slot(role: Codec.Role.watchIdentity, key: "0000", fields: [
            .init(id: Codec.FieldID.accountIDOrAddress, value: Array(repeating: 9, count: 20)),
            .init(id: Codec.FieldID.watchEcosystem, value: [2])
        ])
        var snapshot = Codec.Snapshot(selectedIndex: 0, wallets: [
            .init(
                portableID: [UInt8](repeating: 0x33, count: 16), sourcePosition: 0,
                initialized: true, name: "watch", metadata: metadata, slots: [watch]
            )
        ])
        defer { snapshot.clearSecrets() }
        let encoded = try Codec.encode(snapshot)
        let expectedHex =
            "4650574d534d3031010001000033333333333333333333333333333333000000000100" +
            "057761746368020a0004736f72610b000000010800043030303002070014" +
            "090909090909090909090909090909090909090916000102"
        XCTAssertEqual(encoded.map { String(format: "%02x", $0) }.joined(), expectedHex)
        var decoded = try Codec.decode(encoded)
        defer { decoded.clearSecrets() }
        XCTAssertEqual(decoded.wallets[0].metadata, metadata)
        var plan = try IOSPortableWalletReceiveInstallPlan.prepare(
            encoded, approvedSubstrateGenesisIDs: []
        )
        defer { plan.clearSecrets() }
        XCTAssertEqual(plan.metadataProjections[0]?.androidSelectedChainID, "sora")
        XCTAssertEqual(plan.metadataProjections[0]?.androidChainSelectFilter, "")
        XCTAssertEqual(plan.foreignDisplayPreferenceCandidates.count, 1)
        XCTAssertEqual(plan.foreignDisplayPreferenceCandidates[0].walletIndex, 0)
        XCTAssertEqual(plan.foreignDisplayPreferenceCandidates[0].portableID, Data(repeating: 0x33, count: 16))
        XCTAssertEqual(plan.foreignDisplayPreferenceCandidates[0].destination, .walletBoundSidecar)
        XCTAssertEqual(plan.foreignDisplayPreferenceCandidates[0].androidSelectedChainID, "sora")
        XCTAssertEqual(plan.foreignDisplayPreferenceCandidates[0].androidChainSelectFilter, "")
        XCTAssertTrue(plan.blockers.contains(.unmappedMetadata(2)))
        XCTAssertTrue(plan.blockers.contains(.transactionalInstallerUnavailable))
        XCTAssertEqual(try Codec.encode(plan.snapshot), encoded)
    }

    func testRejectsMalformedAndroidDisplayMetadata() throws {
        XCTAssertThrowsError(try Projection.decode([
            .init(id: MetadataID.androidSelectedChainID, value: [0xFF])
        ]))
        XCTAssertThrowsError(try Projection.decode([
            .init(id: MetadataID.androidChainSelectFilter, value: Array(repeating: 0x61, count: 2049))
        ]))
        XCTAssertThrowsError(try Projection.decode([
            .init(id: MetadataID.androidChainSelectFilter, value: []),
            .init(id: MetadataID.androidSelectedChainID, value: [])
        ]))
        XCTAssertThrowsError(try Projection.decode([.init(id: MetadataID.androidAssetRowPresentation, value: [])]))
        XCTAssertThrowsError(try Projection.decode([.init(id: 13, value: [])]))
    }

    func testAndroidDisplayMetadataCannotSubstituteForIOSNetworkFilter() throws {
        let metadata: [Codec.Metadata] = [
            .init(id: MetadataID.networkManagementFilter, value: Array("all".utf8)),
            .init(id: MetadataID.androidSelectedChainID, value: []),
            .init(id: MetadataID.androidChainSelectFilter, value: Array("All".utf8))
        ]
        let projected = try Projection.decode(metadata)
        XCTAssertEqual(projected.networkManagementFilter, "all")
        XCTAssertEqual(projected.androidSelectedChainID, "")
        XCTAssertEqual(projected.androidChainSelectFilter, "All")
        XCTAssertTrue(NetworkManagmentFilter(identifier: "").isChainSelected)
        XCTAssertEqual(NetworkManagmentFilter(identifier: "").selectedChainId, "")

        let watch = Codec.Slot(role: Codec.Role.watchIdentity, key: "0000", fields: [
            .init(id: Codec.FieldID.accountIDOrAddress, value: Array(repeating: 9, count: 20)),
            .init(id: Codec.FieldID.watchEcosystem, value: [2])
        ])
        var snapshot = Codec.Snapshot(selectedIndex: 0, wallets: [
            .init(
                portableID: [UInt8](repeating: 0x33, count: 16), sourcePosition: 0,
                initialized: true, name: "watch", metadata: metadata, slots: [watch]
            )
        ])
        defer { snapshot.clearSecrets() }
        var plan = try IOSPortableWalletReceiveInstallPlan.prepare(
            Codec.encode(snapshot), approvedSubstrateGenesisIDs: []
        )
        defer { plan.clearSecrets() }
        XCTAssertEqual(plan.metadataProjections[0], projected)
        XCTAssertEqual(plan.foreignDisplayPreferenceCandidates[0].androidSelectedChainID, "")
        XCTAssertEqual(plan.foreignDisplayPreferenceCandidates[0].androidChainSelectFilter, "All")
        XCTAssertTrue(plan.blockers.contains(.unmappedMetadata(3)))
        XCTAssertTrue(plan.blockers.contains(.transactionalInstallerUnavailable))
    }

    func testRejectsDisplayFiltersNotRepresentableInCurrentCoreData() throws {
        let tooMany = (0 ..< 33).map { "filter\($0)" }
        XCTAssertThrowsError(try Projection.decode([
            .init(id: MetadataID.assetFilterOptions, value: stringList(tooMany))
        ]))
        XCTAssertThrowsError(try Projection.decode([
            .init(id: MetadataID.assetFilterOptions, value: stringList([""]))
        ]))
        XCTAssertThrowsError(try Projection.decode([
            .init(id: MetadataID.assetFilterOptions, value: stringList([String(repeating: "x", count: 129)]))
        ]))
    }

    func testRejectsUnsortedOrDuplicateVisibilityKeys() throws {
        XCTAssertThrowsError(try Projection.decode([
            .init(id: MetadataID.assetVisibility, value: visibility([("ETH", false), ("DOT", true)]))
        ]))
        XCTAssertThrowsError(try Projection.decode([
            .init(id: MetadataID.assetVisibility, value: visibility([("DOT", false), ("DOT", true)]))
        ]))
    }

    func testReadOnlyReceivePlanRetainsProjectionAndItsInstallBlocker() throws {
        let watch = Codec.Slot(role: Codec.Role.watchIdentity, key: "0000", fields: [
            .init(id: Codec.FieldID.accountIDOrAddress, value: Array(repeating: 9, count: 20)),
            .init(id: Codec.FieldID.watchEcosystem, value: [2])
        ])
        var snapshot = Codec.Snapshot(selectedIndex: 0, wallets: [
            .init(
                portableID: [UInt8](repeating: 0x33, count: 16), sourcePosition: 0,
                initialized: true, name: "watch", metadata: [
                    .init(id: MetadataID.selectedCurrency, value: Array("JPY".utf8))
                ], slots: [watch]
            )
        ])
        defer { snapshot.clearSecrets() }
        let encoded = try Codec.encode(snapshot)
        var plan = try IOSPortableWalletReceiveInstallPlan.prepare(
            encoded, approvedSubstrateGenesisIDs: []
        )
        defer { plan.clearSecrets() }
        XCTAssertEqual(plan.metadataProjections[0]?.selectedCurrencyID, "JPY")
        XCTAssertTrue(plan.blockers.contains(.unmappedMetadata(1)))
        XCTAssertTrue(plan.blockers.contains(.transactionalInstallerUnavailable))
        XCTAssertEqual(try plan.destinationOrders(after: [6, 6]), [7])
        XCTAssertEqual(try Codec.encode(plan.snapshot), encoded)
    }

    func testDestinationOrdersUseRecordSequenceAndBoundedPositiveCoreDataSpace() throws {
        XCTAssertEqual(try IOSPortableReceiveOrderAllocator.assign(walletCount: 2, after: []), [1, 2])
        XCTAssertEqual(try IOSPortableReceiveOrderAllocator.assign(walletCount: 3, after: [0, 9, 9]), [10, 11, 12])
        XCTAssertEqual(
            try IOSPortableReceiveOrderAllocator.assign(walletCount: 1, after: [UInt32(Int32.max - 1)]),
            [UInt32(Int32.max)]
        )
        XCTAssertThrowsError(
            try IOSPortableReceiveOrderAllocator.assign(walletCount: 2, after: [UInt32(Int32.max - 1)])
        )
        XCTAssertThrowsError(
            try IOSPortableReceiveOrderAllocator.assign(walletCount: 1, after: [UInt32(Int32.max) + 1])
        )
        XCTAssertThrowsError(try IOSPortableReceiveOrderAllocator.assign(walletCount: 0, after: []))
    }

    private func stringList(_ values: [String]) throws -> [UInt8] {
        try IOSPortableWalletSemanticDraftAdapter.stringList(values)
    }

    private func visibility(_ values: [(String, Bool)]) throws -> [UInt8] {
        var writer = Codec.Writer()
        defer { writer.erase() }
        try writer.writeUInt16(values.count)
        for (assetID, hidden) in values {
            try writer.writeText(assetID)
            try writer.write(hidden ? 1 : 0)
        }
        return writer.bytes
    }
}

final class IOSForeignDisplayPrefsTests: XCTestCase {
    private typealias Codec = IOSPortableWalletSemanticMaterial
    private typealias MetadataID = IOSPortableWalletSemanticMaterial.MetadataID
    private typealias Journal = IOSPortableWalletReceiveJournalRecord
    private let firstMetaID = "11111111-1111-4111-a111-111111111111"
    private let secondMetaID = "22222222-2222-4222-8222-222222222222"

    func testForeignDisplaySidecarBindsEachValueToItsDestinationWallet() throws {
        let (encoded, journal) = try sidecarFixture()
        var plan = try IOSPortableWalletReceiveInstallPlan.prepare(
            encoded, approvedSubstrateGenesisIDs: []
        )
        defer { plan.clearSecrets() }
        XCTAssertEqual(plan.foreignDisplayPreferenceCandidates.count, 2)
        XCTAssertEqual(plan.metadataProjections[0]?.networkManagementFilter, "all")
        XCTAssertNil(plan.metadataProjections[1]?.networkManagementFilter)
        XCTAssertEqual(plan.foreignDisplayPreferenceCandidates[0].androidSelectedChainID, "")
        XCTAssertNil(plan.foreignDisplayPreferenceCandidates[0].androidChainSelectFilter)
        XCTAssertNil(plan.foreignDisplayPreferenceCandidates[1].androidSelectedChainID)
        XCTAssertEqual(plan.foreignDisplayPreferenceCandidates[1].androidChainSelectFilter, "All")

        let bound = try plan.prospectiveForeignDisplaySidecars(for: journal)
        XCTAssertEqual(bound.map(\.destinationMetaID), [firstMetaID, secondMetaID])
        XCTAssertEqual(bound.map(\.destination), [.walletBoundSidecar, .walletBoundSidecar])
        XCTAssertEqual(bound[0].androidSelectedChainID, "")
        XCTAssertNil(bound[0].androidChainSelectFilter)
        XCTAssertNil(bound[1].androidSelectedChainID)
        XCTAssertEqual(bound[1].androidChainSelectFilter, "All")
        XCTAssertFalse(String(describing: bound[0]).contains(firstMetaID))
        XCTAssertFalse(String(reflecting: bound[1]).contains("All"))
        XCTAssertTrue(plan.blockers.contains(.unmappedMetadata(3)))
        XCTAssertTrue(plan.blockers.contains(.transactionalInstallerUnavailable))

        let swapped = Journal.Record(
            schemaVersion: journal.schemaVersion, transactionID: journal.transactionID,
            semanticSHA256: journal.semanticSHA256, selectedIndex: journal.selectedIndex,
            wallets: Array(journal.wallets.reversed()), keys: journal.keys, phase: journal.phase
        )
        XCTAssertThrowsError(try plan.prospectiveForeignDisplaySidecars(for: swapped))
        let wrongDigest = Journal.Record(
            schemaVersion: journal.schemaVersion, transactionID: journal.transactionID,
            semanticSHA256: Data(repeating: 0xFF, count: 32), selectedIndex: journal.selectedIndex,
            wallets: journal.wallets, keys: journal.keys, phase: journal.phase
        )
        XCTAssertThrowsError(try plan.prospectiveForeignDisplaySidecars(for: wrongDigest))
    }

    func testIOSNetworkFilterAloneDoesNotCreateForeignDisplaySidecar() throws {
        let watch = Codec.Slot(role: Codec.Role.watchIdentity, key: "0000", fields: [
            .init(id: Codec.FieldID.accountIDOrAddress, value: Array(repeating: 9, count: 20)),
            .init(id: Codec.FieldID.watchEcosystem, value: [2])
        ])
        var snapshot = Codec.Snapshot(selectedIndex: 0, wallets: [
            .init(
                portableID: [UInt8](repeating: 0x44, count: 16),
                sourcePosition: 0,
                initialized: true,
                name: "watch",
                metadata: [
                    .init(id: MetadataID.networkManagementFilter, value: [])
                ],
                slots: [watch]
            )
        ])
        defer { snapshot.clearSecrets() }
        var plan = try IOSPortableWalletReceiveInstallPlan.prepare(
            Codec.encode(snapshot), approvedSubstrateGenesisIDs: []
        )
        defer { plan.clearSecrets() }
        XCTAssertEqual(plan.metadataProjections[0]?.networkManagementFilter, "")
        XCTAssertTrue(plan.foreignDisplayPreferenceCandidates.isEmpty)
        XCTAssertTrue(plan.blockers.contains(.unmappedMetadata(1)))
        XCTAssertTrue(plan.blockers.contains(.transactionalInstallerUnavailable))
    }

    private func sidecarFixture() throws -> (Data, Journal.Record) {
        let watch = Codec.Slot(role: Codec.Role.watchIdentity, key: "0000", fields: [
            .init(id: Codec.FieldID.accountIDOrAddress, value: Array(repeating: 9, count: 20)),
            .init(id: Codec.FieldID.watchEcosystem, value: [2])
        ])
        let first = Codec.Wallet(
            portableID: [UInt8](repeating: 0x11, count: 16), sourcePosition: 0,
            initialized: true, name: "first", metadata: [
                .init(id: MetadataID.networkManagementFilter, value: Array("all".utf8)),
                .init(id: MetadataID.androidSelectedChainID, value: [])
            ], slots: [watch]
        )
        let second = Codec.Wallet(
            portableID: [UInt8](repeating: 0x22, count: 16), sourcePosition: 1,
            initialized: true, name: "second", metadata: [
                .init(id: MetadataID.androidChainSelectFilter, value: Array("All".utf8))
            ], slots: [watch]
        )
        var snapshot = Codec.Snapshot(selectedIndex: 1, wallets: [first, second])
        defer { snapshot.clearSecrets() }
        let encoded = try Codec.encode(snapshot)
        let journal = Journal.Record(
            schemaVersion: Journal.schemaVersion,
            transactionID: "33333333-3333-4333-8333-333333333333",
            semanticSHA256: Data(SHA256.hash(data: encoded)), selectedIndex: 1,
            wallets: [
                .init(metaID: firstMetaID, portableID: Data(first.portableID)),
                .init(metaID: secondMetaID, portableID: Data(second.portableID))
            ], keys: [], phase: .staging
        )
        return (encoded, journal)
    }
}
