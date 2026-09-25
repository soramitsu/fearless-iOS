@testable import fearless
import CryptoKit
import Foundation
import XCTest

final class IOSPortableWalletAssetPresentationTests: XCTestCase {
    private typealias Codec = IOSPortableWalletSemanticMaterial
    private typealias MetadataID = IOSPortableWalletSemanticMaterial.MetadataID

    func testPreservesGenericAndScopedRows() throws {
        let rows = try alternateRows()
        let parsed = try Codec.decodeAssetRowPresentation(rows)
        XCTAssertEqual(parsed.map(\.accountID), [[], [1]])
        XCTAssertNil(parsed[0].enabled)
        XCTAssertEqual(parsed[0].sortIndex, Int32.max)
        XCTAssertTrue(parsed[0].markedNotNeed)
        XCTAssertNil(parsed[0].chainAccountName)
        XCTAssertEqual(parsed[1].enabled, true)
        XCTAssertEqual(parsed[1].sortIndex, -2)
        XCTAssertEqual(parsed[1].chainAccountName, "")
        XCTAssertTrue(String(reflecting: parsed[1]).contains("<redacted>"))
        var snapshot = watchSnapshot(metadata: [
            .init(id: MetadataID.androidAssetRowPresentation, value: rows)
        ])
        defer { snapshot.clearSecrets() }
        let encoded = try Codec.encode(snapshot)
        var decoded = try Codec.decode(encoded)
        defer { decoded.clearSecrets() }
        XCTAssertEqual(decoded.wallets[0].metadata[0].value, rows)
        XCTAssertEqual(try Codec.encode(decoded), encoded)
    }

    func testRejectsAmbiguousAndMalformedRows() throws {
        let valid = try alternateRows()
        var invalidUTF8 = valid
        invalidUTF8[5] = 0xFF
        let invalidEnabled = try alternateRows(enabledCode: 3)
        let invalidMarked = try alternateRows(markedCode: 2)
        let invalidNameFlag = try alternateRows(namePresentCode: 2)
        let reversed = try alternateRows(reverseAccountOrder: true)
        let duplicate = try alternateRows(duplicateAccountOrder: true)
        let defaultRow = try alternateRows(defaultFirstRow: true)
        let emptyChain = try alternateRows(firstChainID: "")
        var oversizedAccount = valid
        oversizedAccount[14] = 0
        oversizedAccount[15] = 129
        let denied: [[UInt8]] = [
            [], [0, 0, 1], [1, 0, 0], Array(valid.dropLast()), valid + [0],
            invalidEnabled, invalidMarked, invalidNameFlag,
            reversed, duplicate, defaultRow, emptyChain, invalidUTF8,
            oversizedAccount, Array(repeating: 0, count: 32769)
        ]
        for bytes in denied {
            XCTAssertThrowsError(try Codec.decodeAssetRowPresentation(bytes))
            var snapshot = watchSnapshot(metadata: [
                .init(id: MetadataID.androidAssetRowPresentation, value: bytes)
            ])
            defer { snapshot.clearSecrets() }
            XCTAssertThrowsError(try Codec.encode(snapshot))
        }
    }

    func testCanonicallyEquivalentChainNamesStillSortByRawUTF8() throws {
        let decomposed = "e\u{301}"
        let composed = "\u{E9}"
        XCTAssertEqual(decomposed, composed)
        XCTAssertNotEqual(Array(decomposed.utf8), Array(composed.utf8))
        let ascending = try unicodeRows(first: decomposed, second: composed)
        let decoded = try Codec.decodeAssetRowPresentation(ascending)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertNotEqual(decoded[0], decoded[1])
        let descending = try unicodeRows(first: composed, second: decomposed)
        XCTAssertThrowsError(try Codec.decodeAssetRowPresentation(descending))
    }

    func testAndroidVectorProjectsRowsAndStaysInstallBlocked() throws {
        let rows = try androidVectorRows()
        XCTAssertEqual(rows.count, 53)
        let metadata: [Codec.Metadata] = [
            .init(id: MetadataID.androidSelectedChainID, value: Array("sora".utf8)),
            .init(id: MetadataID.androidChainSelectFilter, value: []),
            .init(id: MetadataID.androidAssetRowPresentation, value: rows)
        ]
        let projected = try IOSPortableReceiveMetadata.decode(metadata)
        XCTAssertEqual(projected.androidAssetRows?.count, 2)
        XCTAssertEqual(projected.androidAssetRows?[0].accountID, [])
        XCTAssertEqual(projected.androidAssetRows?[0].enabled, true)
        XCTAssertEqual(projected.androidAssetRows?[0].sortIndex, -2)
        XCTAssertTrue(projected.androidAssetRows?[0].markedNotNeed == true)
        XCTAssertEqual(projected.androidAssetRows?[0].chainAccountName, "")
        XCTAssertEqual(projected.androidAssetRows?[1].accountID, [0x01, 0x80])
        XCTAssertEqual(projected.androidAssetRows?[1].enabled, false)
        XCTAssertEqual(projected.androidAssetRows?[1].sortIndex, Int32.max)
        XCTAssertEqual(projected.androidAssetRows?[1].chainAccountName, "Main")
        XCTAssertNil(try IOSPortableReceiveMetadata.decode([]).androidAssetRows)

        var snapshot = watchSnapshot(metadata: metadata)
        defer { snapshot.clearSecrets() }
        let encoded = try Codec.encode(snapshot)
        XCTAssertEqual(encoded.count, 126)
        XCTAssertEqual(encoded.map { String(format: "%02x", $0) }.joined(), androidVectorHex)
        XCTAssertEqual(
            SHA256.hash(data: encoded).map { String(format: "%02x", $0) }.joined(),
            "842124d8aa738dc490b5f1366470f9e3183158514236b3c6ba4758bb927a66ab"
        )
        var plan = try IOSPortableWalletReceiveInstallPlan.prepare(
            encoded, approvedSubstrateGenesisIDs: []
        )
        defer { plan.clearSecrets() }
        XCTAssertEqual(plan.metadataProjections[0]?.androidAssetRows, projected.androidAssetRows)
        XCTAssertTrue(plan.blockers.contains(.unmappedMetadata(3)))
        XCTAssertTrue(plan.blockers.contains(.transactionalInstallerUnavailable))
        XCTAssertEqual(try Codec.encode(plan.snapshot), encoded)
    }

    private func watchSnapshot(metadata: [Codec.Metadata]) -> Codec.Snapshot {
        let watch = Codec.Slot(role: Codec.Role.watchIdentity, key: "0000", fields: [
            .init(id: Codec.FieldID.accountIDOrAddress, value: [9]),
            .init(id: Codec.FieldID.watchEcosystem, value: [2])
        ])
        return Codec.Snapshot(selectedIndex: 0, wallets: [
            .init(
                portableID: [UInt8](repeating: 0x33, count: 16), sourcePosition: 0,
                initialized: true, name: "watch", metadata: metadata, slots: [watch]
            )
        ])
    }

    private func alternateRows(
        firstChainID: String = "sora", enabledCode: UInt8 = 0,
        markedCode: UInt8 = 1, namePresentCode: UInt8 = 0,
        reverseAccountOrder: Bool = false, duplicateAccountOrder: Bool = false,
        defaultFirstRow: Bool = false
    ) throws -> [UInt8] {
        var writer = Codec.Writer()
        defer { writer.erase() }
        try writer.write(1)
        try writer.writeUInt16(2)
        try writer.writeText(firstChainID)
        try writer.writeText("xor")
        try writer.writeValue(reverseAccountOrder ? [1] : [])
        try writer.write(defaultFirstRow ? 0 : enabledCode)
        try writer.writeUInt32(UInt32(bitPattern: Int32.max))
        try writer.write(defaultFirstRow ? 0 : markedCode)
        try writer.write(namePresentCode)
        if namePresentCode == 1 {
            try writer.writeText("")
        }
        try writer.writeText("sora")
        try writer.writeText("xor")
        try writer.writeValue(reverseAccountOrder || duplicateAccountOrder ? [] : [1])
        try writer.write(2)
        try writer.writeUInt32(UInt32(bitPattern: Int32(-2)))
        try writer.write(0)
        try writer.write(1)
        try writer.writeText("")
        return writer.bytes
    }

    private func androidVectorRows() throws -> [UInt8] {
        var writer = Codec.Writer()
        defer { writer.erase() }
        try writer.write(1)
        try writer.writeUInt16(2)
        try writer.writeText("sora")
        try writer.writeText("dot")
        try writer.writeValue([])
        try writer.write(2)
        try writer.writeUInt32(UInt32(bitPattern: Int32(-2)))
        try writer.write(1)
        try writer.write(1)
        try writer.writeText("")
        try writer.writeText("sora")
        try writer.writeText("dot")
        try writer.writeValue([0x01, 0x80])
        try writer.write(1)
        try writer.writeUInt32(UInt32(bitPattern: Int32.max))
        try writer.write(0)
        try writer.write(1)
        try writer.writeText("Main")
        return writer.bytes
    }

    private func unicodeRows(first: String, second: String) throws -> [UInt8] {
        var writer = Codec.Writer()
        defer { writer.erase() }
        try writer.write(1)
        try writer.writeUInt16(2)
        for chainID in [first, second] {
            try writer.writeText(chainID)
            try writer.writeText("xor")
            try writer.writeValue([])
            try writer.write(2)
            try writer.writeUInt32(UInt32(bitPattern: Int32.max))
            try writer.write(0)
            try writer.write(0)
        }
        return writer.bytes
    }

    private let androidVectorHex =
        "4650574d534d3031010001000033333333333333333333333333333333000000000100" +
        "057761746368030a0004736f72610b00000c00350100020004736f72610003646f" +
        "74000002fffffffe010100000004736f72610003646f7400020180017fffffff0001" +
        "00044d61696e000108000430303030020700010916000102"
}
