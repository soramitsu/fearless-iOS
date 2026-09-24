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
            .init(id: Codec.FieldID.accountIDOrAddress, value: [9]),
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
        XCTAssertEqual(try Codec.encode(plan.snapshot), encoded)
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
