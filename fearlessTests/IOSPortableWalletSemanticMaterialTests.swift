@testable import fearless
import CryptoKit
import Foundation
import XCTest

final class IOSPortableWalletSemanticMaterialTests: XCTestCase {
    private typealias Codec = IOSPortableWalletSemanticMaterial
    private typealias Role = IOSPortableWalletSemanticMaterial.Role
    private typealias FieldID = IOSPortableWalletSemanticMaterial.FieldID
    private typealias MetadataID = IOSPortableWalletSemanticMaterial.MetadataID

    func testDecodesAndReencodesActualAndroidEVMGoldenBytes() throws {
        let androidBytes = try data(hex: evmGoldenHex)
        var decoded = try Codec.decode(androidBytes)
        defer { decoded.clearSecrets() }

        XCTAssertEqual(decoded.selectedIndex, 0)
        XCTAssertEqual(decoded.wallets.count, 1)
        XCTAssertEqual(decoded.wallets[0].sourcePosition, 7)
        XCTAssertEqual(decoded.wallets[0].name, "E")
        XCTAssertEqual(decoded.wallets[0].slots[0].role, Role.evmRoot)
        XCTAssertEqual(try decoded.wallets[0].slots[0].value(FieldID.privateKey), [4])
        XCTAssertEqual(try Codec.encode(decoded), androidBytes)
        XCTAssertEqual(try Codec.encode(evmSnapshot()), androidBytes)

        let wrapped = try IOSPortableWalletMaterialEnvelope.encode(.init(
            origin: .android, sourceFormat: .portableSemanticV1,
            derivationMode: .portable, payload: androidBytes
        ))
        let outer = try IOSPortableWalletMaterialEnvelope.decode(wrapped)
        XCTAssertEqual(outer.payload, androidBytes)
        XCTAssertEqual(try Codec.encode(Codec.decode(outer.payload)), outer.payload)
    }

    func testMultiRootTonChainV1AndAuxiliaryMatchesAndroidDigest() throws {
        var source = multiRootSnapshot()
        defer { source.clearSecrets() }
        let encoded = try Codec.encode(source)
        XCTAssertEqual(sha256(encoded), multiRootSHA256)

        var decoded = try Codec.decode(encoded)
        defer { decoded.clearSecrets() }
        XCTAssertEqual(try Codec.encode(decoded), encoded)
        XCTAssertEqual(decoded.wallets[0].slots.map(\.role), [1, 2, 3, 4, 5, 6, 7, 7])
        XCTAssertEqual(try decoded.wallets[0].slots[6].value(FieldID.sourceBytes), [0x55])
        XCTAssertEqual(try decoded.wallets[0].slots[7].value(FieldID.sourceBytes), [0x66])
        XCTAssertEqual(decoded.wallets[0].metadata.map(\.id), [1, 5, 8])
    }

    func testAllNineMetadataValuesMatchAndroidDigestAndRoundtrip() throws {
        let metadata = [
            Codec.Metadata(id: MetadataID.assetKeysOrder, value: stringList("DOT", "ETH")),
            Codec.Metadata(id: MetadataID.unusedChainIDs, value: stringList("sora")),
            Codec.Metadata(id: MetadataID.selectedCurrency, value: Array("USD".utf8)),
            Codec.Metadata(id: MetadataID.networkManagementFilter, value: Array("all".utf8)),
            Codec.Metadata(id: MetadataID.assetVisibility, value: visibility("DOT", true)),
            Codec.Metadata(id: MetadataID.favoriteChainIDs, value: stringList("sora")),
            Codec.Metadata(id: MetadataID.assetFilterOptions, value: stringList("hidden", "visible")),
            Codec.Metadata(id: MetadataID.zeroBalanceAssetsHidden, value: [1]),
            Codec.Metadata(id: MetadataID.canExportEthereumMnemonic, value: [0])
        ]
        var source = Codec.Snapshot(selectedIndex: 0, wallets: [wallet(metadata: metadata, slots: [evmSlot()])])
        defer { source.clearSecrets() }
        let encoded = try Codec.encode(source)
        XCTAssertEqual(sha256(encoded), fullMetadataSHA256)
        var decoded = try Codec.decode(encoded)
        defer { decoded.clearSecrets() }
        XCTAssertEqual(decoded.wallets[0].metadata, metadata)
        XCTAssertEqual(try Codec.encode(decoded), encoded)
    }

    func testOrderedWalletsSelectionAndAddressOnlyWatchIdentityRoundtrip() throws {
        let watch = slot(Role.watchIdentity, "0000", [
            field(FieldID.accountIDOrAddress, [9]),
            field(FieldID.watchEcosystem, [2])
        ])
        var source = Codec.Snapshot(selectedIndex: 1, wallets: [
            wallet(slots: [evmSlot()]),
            wallet(idStart: 32, position: 3, slots: [watch])
        ])
        defer { source.clearSecrets() }
        let encoded = try Codec.encode(source)
        var decoded = try Codec.decode(encoded)
        defer { decoded.clearSecrets() }
        XCTAssertEqual(decoded.selectedIndex, 1)
        XCTAssertEqual(decoded.wallets.map(\.sourcePosition), [7, 3])
        XCTAssertEqual(decoded.wallets[1].portableID, source.wallets[1].portableID)
        XCTAssertEqual(decoded.wallets[1].slots[0].fields.map(\.id), [7, 22])
        XCTAssertEqual(try Codec.encode(decoded), encoded)
    }

    func testRejectsMalformedUnknownNoncanonicalAndOversizedAndroidBytes() throws {
        let valid = try data(hex: evmGoldenHex)
        var malformed = [Data(valid.dropLast()), valid + Data([0])]
        let mutations: [(Int, UInt8)] = [
            (0, 0), (8, 2), (10, 0), (11, 1), (33, 2),
            (36, 0xFF), (40, 99), (43, 5), (44, 99)
        ]
        for (offset, replacement) in mutations {
            var candidate = valid
            candidate[offset] = replacement
            malformed.append(candidate)
        }
        malformed.append(Data(repeating: 0, count: 256 * 1024 - 44 - 16 + 1))
        for candidate in malformed {
            XCTAssertThrowsError(try Codec.decode(candidate))
        }
    }

    func testRejectsDuplicateIdentitiesFieldsUnorderedSlotsAndMetadata() throws {
        let same = wallet(slots: [evmSlot()])
        XCTAssertThrowsError(try Codec.encode(.init(selectedIndex: 0, wallets: [same, same])))
        let duplicateField = Codec.Slot(role: Role.evmRoot, key: "", fields: [
            field(FieldID.publicKey, [1]), field(FieldID.publicKey, [1]),
            field(FieldID.privateKey, [2]), field(FieldID.accountIDOrAddress, [3]),
            field(FieldID.sourceRecipe, [0])
        ])
        XCTAssertThrowsError(try Codec.encode(.init(
            selectedIndex: 0, wallets: [wallet(slots: [duplicateField])]
        )))
        XCTAssertThrowsError(try Codec.encode(.init(
            selectedIndex: 0, wallets: [wallet(slots: [watchEVMSlot(), evmSlot()])]
        )))
        let duplicateMetadata = [
            Codec.Metadata(id: MetadataID.selectedCurrency, value: Array("USD".utf8)),
            Codec.Metadata(id: MetadataID.selectedCurrency, value: Array("EUR".utf8))
        ]
        XCTAssertThrowsError(try Codec.encode(.init(
            selectedIndex: 0, wallets: [wallet(metadata: duplicateMetadata, slots: [evmSlot()])]
        )))
        let unknownMetadata = [Codec.Metadata(id: 12, value: [1])]
        XCTAssertThrowsError(try Codec.encode(.init(
            selectedIndex: 0, wallets: [wallet(metadata: unknownMetadata, slots: [evmSlot()])]
        )))
    }

    func testTonRootAndWatchRequireV4R2AndAddressEncodingShape() throws {
        let signed = slot(Role.tonRoot, "", [
            field(FieldID.publicKey, [7]), field(FieldID.privateKey, [8]),
            field(FieldID.accountIDOrAddress, (0 ... 32).map { UInt8($0) }),
            field(FieldID.sourceRecipe, [0]), field(FieldID.tonContractVersion, [2]),
            field(FieldID.tonAddressEncoding, [1])
        ])
        let jsonWatch = slot(Role.watchIdentity, "0000", [
            field(FieldID.accountIDOrAddress, Array("{}".utf8)),
            field(FieldID.tonContractVersion, [2]), field(FieldID.tonAddressEncoding, [2]),
            field(FieldID.watchEcosystem, [3])
        ])
        XCTAssertNoThrow(try Codec.encode(.init(selectedIndex: 0, wallets: [wallet(slots: [signed])])))
        XCTAssertNoThrow(try Codec.encode(.init(selectedIndex: 0, wallets: [wallet(slots: [jsonWatch])])))
        for validSlot in [signed, jsonWatch] {
            let encoded = try Codec.encode(.init(selectedIndex: 0, wallets: [wallet(slots: [validSlot])]))
            guard let versionField = encoded.range(of: Data([FieldID.tonContractVersion, 0, 1, 2])) else {
                XCTFail("Missing TON contract version in synthetic vector")
                continue
            }
            for unsupportedVersion in [UInt8(0), UInt8(1)] {
                var malformed = encoded
                malformed[versionField.upperBound - 1] = unsupportedVersion
                XCTAssertThrowsError(try Codec.decode(malformed))
            }
        }
        for unsupportedVersion in [UInt8(0), UInt8(1)] {
            let candidate = replacing(signed, fieldID: FieldID.tonContractVersion, with: [unsupportedVersion])
            XCTAssertThrowsError(try Codec.encode(.init(
                selectedIndex: 0, wallets: [wallet(slots: [candidate])]
            )))
            let watchCandidate = replacing(jsonWatch, fieldID: FieldID.tonContractVersion, with: [unsupportedVersion])
            XCTAssertThrowsError(try Codec.encode(.init(
                selectedIndex: 0, wallets: [wallet(slots: [watchCandidate])]
            )))
        }
        XCTAssertThrowsError(try Codec.encode(.init(selectedIndex: 0, wallets: [wallet(slots: [
            replacing(signed, fieldID: FieldID.accountIDOrAddress, with: [1, 2, 3])
        ])])))
        XCTAssertThrowsError(try Codec.encode(.init(selectedIndex: 0, wallets: [wallet(slots: [
            replacing(jsonWatch, fieldID: FieldID.accountIDOrAddress, with: [0xFF])
        ])])))
    }

    func testAuxiliarySourceRequiresExactRoleFormatBindingAndSemanticMaterial() throws {
        let walletBoundStray = slot(Role.auxiliarySource, "0000", [
            field(FieldID.sourceRecipe, [0]), field(FieldID.sourcePlatform, [2]),
            field(FieldID.sourceSlotRole, [3]), field(FieldID.bindingKind, [1]),
            field(FieldID.sourceFormat, [1]), field(FieldID.sourceBytes, [0x42])
        ])
        XCTAssertNoThrow(try Codec.encode(.init(
            selectedIndex: 0, wallets: [wallet(slots: [walletBoundStray, watchEVMSlot()])]
        )))
        XCTAssertThrowsError(try Codec.encode(.init(
            selectedIndex: 0, wallets: [wallet(slots: [walletBoundStray])]
        )))
        XCTAssertThrowsError(try Codec.encode(.init(
            selectedIndex: 0, wallets: [wallet(slots: [
                evmSlot(), replacing(walletBoundStray, fieldID: FieldID.sourceSlotRole, with: [10])
            ])]
        )))
        let chainBound = slot(Role.auxiliarySource, "0000", [
            field(FieldID.sourceRecipe, [0]), field(FieldID.sourcePlatform, [1]),
            field(FieldID.sourceSlotRole, [14]), field(FieldID.bindingKind, [5]),
            field(FieldID.bindingChainID, Array("missing".utf8)),
            field(FieldID.sourceFormat, [3]), field(FieldID.sourceBytes, [1]),
            field(FieldID.bindingAccountID, [2])
        ])
        XCTAssertThrowsError(try Codec.encode(.init(
            selectedIndex: 0, wallets: [wallet(slots: [evmSlot(), chainBound])]
        )))
    }

    func testFavoriteSourcesAreMutuallyExclusive() throws {
        let favorite = slot(Role.favoriteChain, "chain", [field(FieldID.initializedOrFavorite, [1])])
        let list = Codec.Metadata(id: MetadataID.favoriteChainIDs, value: stringList("chain"))
        XCTAssertThrowsError(try Codec.encode(.init(selectedIndex: 0, wallets: [
            wallet(metadata: [list], slots: [evmSlot(), favorite])
        ])))
    }

    func testBestEffortClearAndIntrospectionRedactSecretArrays() {
        var source = multiRootSnapshot()
        let wallet = source.wallets[0]
        let slot = wallet.slots[0]
        let metadata = wallet.metadata[0]
        let field = slot.fields[0]
        let models: [Any] = [source, wallet, slot, metadata, field]
        for model in models {
            XCTAssertTrue(String(describing: model).contains("<redacted>"))
            XCTAssertTrue(String(reflecting: model).contains("<redacted>"))
            let mirrorValues = Mirror(reflecting: model).children.map { String(describing: $0.value) }
            XCTAssertEqual(mirrorValues.count, 1)
            XCTAssertTrue(mirrorValues[0].contains("<redacted>"))
        }

        source.clearSecrets()
        for clearedWallet in source.wallets {
            XCTAssertTrue(clearedWallet.portableID.allSatisfy { $0 == 0 })
            for item in clearedWallet.metadata {
                XCTAssertTrue(item.value.allSatisfy { $0 == 0 })
            }
            for clearedSlot in clearedWallet.slots {
                for clearedField in clearedSlot.fields {
                    XCTAssertTrue(clearedField.value.allSatisfy { $0 == 0 })
                }
            }
        }
    }

    private func evmSnapshot() -> Codec.Snapshot {
        Codec.Snapshot(selectedIndex: 0, wallets: [wallet(slots: [evmSlot()])])
    }

    private func evmSlot() -> Codec.Slot {
        slot(Role.evmRoot, "", [
            field(FieldID.publicKey, [2, 3]), field(FieldID.privateKey, [4]),
            field(FieldID.accountIDOrAddress, [5]), field(FieldID.sourceRecipe, [0])
        ])
    }

    private func watchEVMSlot() -> Codec.Slot {
        slot(Role.watchIdentity, "0000", [
            field(FieldID.accountIDOrAddress, [9]), field(FieldID.watchEcosystem, [2])
        ])
    }

    private func multiRootSnapshot() -> Codec.Snapshot {
        let chainID = "chain-a"
        let slots = [
            slot(Role.substrateRoot, "", [
                field(FieldID.publicKey, [1]), field(FieldID.privateKey, [2]),
                field(FieldID.accountIDOrAddress, [3]), field(FieldID.cryptoType, [1]),
                field(FieldID.sourceRecipe, [0])
            ]),
            slot(Role.evmRoot, "", [
                field(FieldID.publicKey, [4]), field(FieldID.privateKey, [5]),
                field(FieldID.accountIDOrAddress, [6]), field(FieldID.sourceRecipe, [0])
            ]),
            slot(Role.tonRoot, "", [
                field(FieldID.publicKey, [7]), field(FieldID.privateKey, [8]),
                field(FieldID.seed, [9]), field(FieldID.accountIDOrAddress, (0 ... 32).map { UInt8($0) }),
                field(FieldID.sourceRecipe, [0]), field(FieldID.tonContractVersion, [2]),
                field(FieldID.tonAddressEncoding, [1])
            ]),
            slot(Role.legacySubstrate, "", [
                field(FieldID.publicKey, [1]), field(FieldID.privateKey, [10]),
                field(FieldID.seed, [11]), field(FieldID.accountIDOrAddress, Array("5abc".utf8)),
                field(FieldID.cryptoType, [1]), field(FieldID.sourceRecipe, [2])
            ]),
            slot(Role.chainAccount, chainID, [
                field(FieldID.publicKey, [12]), field(FieldID.privateKey, [13]),
                field(FieldID.accountIDOrAddress, [14]), field(FieldID.cryptoType, [1]),
                field(FieldID.chainName, Array("Chain".utf8)),
                field(FieldID.initializedOrFavorite, [1]), field(FieldID.sourceRecipe, [0])
            ]),
            slot(Role.favoriteChain, "chain-z", [field(FieldID.initializedOrFavorite, [1])]),
            slot(Role.auxiliarySource, "0000", [
                field(FieldID.sourceRecipe, [0]), field(FieldID.sourcePlatform, [2]),
                field(FieldID.sourceSlotRole, [9]), field(FieldID.bindingKind, [1]),
                field(FieldID.sourceFormat, [1]), field(FieldID.sourceBytes, [0x55])
            ]),
            slot(Role.auxiliarySource, "0001", [
                field(FieldID.sourceRecipe, [0]), field(FieldID.sourcePlatform, [1]),
                field(FieldID.sourceSlotRole, [14]), field(FieldID.bindingKind, [5]),
                field(FieldID.bindingChainID, Array(chainID.utf8)), field(FieldID.sourceFormat, [3]),
                field(FieldID.sourceBytes, [0x66]), field(FieldID.bindingAccountID, [14])
            ])
        ]
        let metadata = [
            Codec.Metadata(id: MetadataID.assetKeysOrder, value: stringList("DOT", "ETH")),
            Codec.Metadata(id: MetadataID.assetVisibility, value: visibility("DOT", true)),
            Codec.Metadata(id: MetadataID.zeroBalanceAssetsHidden, value: [1])
        ]
        return Codec.Snapshot(selectedIndex: 0, wallets: [
            wallet(idStart: 0xA0, position: 9, name: "All", metadata: metadata, slots: slots)
        ])
    }

    private func wallet(
        idStart: UInt8 = 1,
        position: UInt32 = 7,
        name: String = "E",
        metadata: [Codec.Metadata] = [],
        slots: [Codec.Slot]
    ) -> Codec.Wallet {
        Codec.Wallet(
            portableID: (0 ..< 16).map { UInt8(Int(idStart) + $0) },
            sourcePosition: position, initialized: true, name: name,
            metadata: metadata, slots: slots
        )
    }

    private func slot(_ role: UInt8, _ key: String, _ fields: [Codec.Field]) -> Codec.Slot {
        Codec.Slot(role: role, key: key, fields: fields.sorted { $0.id < $1.id })
    }

    private func field(_ id: UInt8, _ value: [UInt8]) -> Codec.Field {
        Codec.Field(id: id, value: value)
    }

    private func replacing(_ slot: Codec.Slot, fieldID: UInt8, with bytes: [UInt8]) -> Codec.Slot {
        Codec.Slot(role: slot.role, key: slot.key, fields: slot.fields.map {
            $0.id == fieldID ? Codec.Field(id: fieldID, value: bytes) : $0
        })
    }

    private func stringList(_ values: String...) -> [UInt8] {
        var result = [UInt8(UInt16(values.count) >> 8), UInt8(values.count & 0xFF)]
        for value in values {
            let bytes = Array(value.utf8)
            result.append(UInt8((bytes.count >> 8) & 0xFF))
            result.append(UInt8(bytes.count & 0xFF))
            result.append(contentsOf: bytes)
        }
        return result
    }

    private func visibility(_ key: String, _ visible: Bool) -> [UInt8] {
        let bytes = Array(key.utf8)
        return [0, 1, UInt8((bytes.count >> 8) & 0xFF), UInt8(bytes.count & 0xFF)] +
            bytes + [visible ? 1 : 0]
    }

    private func data(hex: String) throws -> Data {
        guard hex.count.isMultiple(of: 2) else { throw Codec.CodecError.invalidMaterial }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        for offset in stride(from: 0, to: hex.count, by: 2) {
            let start = hex.index(hex.startIndex, offsetBy: offset)
            let end = hex.index(start, offsetBy: 2)
            guard let byte = UInt8(hex[start ..< end], radix: 16) else {
                throw Codec.CodecError.invalidMaterial
            }
            bytes.append(byte)
        }
        return Data(bytes)
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private let evmGoldenHex =
        "4650574d534d303101000100000102030405060708090a0b0c0d0e0f10000000070100014500000102000004010002020302000104070001050b000100"
    private let multiRootSHA256 =
        "784647ca5aa76953d4d19404d7fe78c461b9df329a2dd698cc8b5cc18b49d22c"
    private let fullMetadataSHA256 =
        "181f843dcbafbd0ba151a7476b1f63c3a6060df9c9fd45055869ff8383608b16"
}
