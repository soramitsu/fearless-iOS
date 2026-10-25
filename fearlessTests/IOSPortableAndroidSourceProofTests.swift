@testable import fearless
import Foundation
import XCTest

final class IOSPortableAndroidSourceProofTests: XCTestCase {
    private typealias Codec = IOSPortableWalletSemanticMaterial
    private typealias FieldID = IOSPortableWalletSemanticMaterial.FieldID
    private typealias Proof = IOSPortableAndroidSourceProof

    func testVerifiesCanonicalSubstrateEvmAndChainKeypairSources() throws {
        for (rootRole, sourceRole, binding) in [(UInt8(1), UInt8(11), UInt8(2)),
                                                (2, 12, 3), (5, 14, 5)] {
            let root = primary(role: rootRole)
            let raw: [UInt8] = [1] + scaleBytes([0xE1]) + [1] + scaleBytes([0xD4]) +
                scaleBytes([0xA1]) + scaleBytes([0xB2]) + [1] +
                scaleBytes([0xC3]) + [1] + scaleBytes(Array("//test".utf8))
            let auxiliary = source(role: sourceRole, binding: binding, bytes: raw)
            // Both platform codecs require a signed root in a cohort wallet.
            let slots = rootRole == 5 ? [primary(role: 2), root, auxiliary] : [root, auxiliary]
            let encoded = try material(slots: slots)
            let counts = try Proof.verify(encoded)
            XCTAssertEqual(counts, .init(verifiedSources: 1), "source role \(sourceRole)")
        }
    }

    func testVerifiesCanonicalTonAndLegacySources() throws {
        let ton = primary(role: 3)
        let tonRaw = scaleBytes(Array("seed".utf8)) + scaleBytes([0xA1]) + scaleBytes([0xB2])
        XCTAssertEqual(try Proof.verify(material(slots: [
            ton, source(role: 13, binding: 4, bytes: tonRaw)
        ])).verifiedSources, 1)

        let legacy = primary(role: 4)
        let legacyRaw = scaleBytes(Array("SEED".utf8)) + scaleBytes([0xA1]) +
            scaleBytes([0xB2]) + [1] + scaleBytes([0xC3]) +
            [1] + scaleBytes([0xD4]) + [0, 1] + scaleBytes(Array("//test".utf8))
        XCTAssertEqual(try Proof.verify(material(slots: [
            legacy, source(role: 10, binding: 2, bytes: legacyRaw, format: 2)
        ])).verifiedSources, 1)
    }

    func testVerifiesCanonicalTwoByteScaleLength() throws {
        var root = primary(role: 2)
        let entropy = Array(repeating: UInt8(0xE1), count: 64)
        let entropyIndex = try XCTUnwrap(root.fields.firstIndex { $0.id == FieldID.entropy })
        root.fields[entropyIndex].value = entropy
        let raw: [UInt8] = [1] + scaleBytes(entropy) + [1] + scaleBytes([0xD4]) +
            scaleBytes([0xA1]) + scaleBytes([0xB2]) + [1] +
            scaleBytes([0xC3]) + [1] + scaleBytes(Array("//test".utf8))
        let encoded = try material(slots: [root, source(role: 12, binding: 3, bytes: raw)])
        XCTAssertEqual(try Proof.verify(encoded).verifiedSources, 1)
    }

    func testRejectsChangedFieldsNoncanonicalLengthsOptionsAndTrailingBytes() throws {
        let root = primary(role: 2)
        let valid: [UInt8] = [1] + scaleBytes([0xE1]) + [1] + scaleBytes([0xD4]) +
            scaleBytes([0xA1]) + scaleBytes([0xB2]) + [1] +
            scaleBytes([0xC3]) + [1] + scaleBytes(Array("//test".utf8))
        let variants: [[UInt8]] = [
            Array(valid.dropLast()), valid + [0],
            [2] + Array(valid.dropFirst()),
            [1, 5, 0, 0xE1] + Array(valid.dropFirst(3)),
            [1, 0x04, 0xE2] + Array(valid.dropFirst(3)),
            [1, 0x03] + Array(valid.dropFirst(2))
        ]
        for candidate in variants {
            XCTAssertThrowsError(try Proof.verify(material(slots: [
                root, source(role: 12, binding: 3, bytes: candidate)
            ])))
        }
    }

    func testRejectsWrongChainBindingAndLegacySourceType() throws {
        let chain = primary(role: 5)
        let raw: [UInt8] = [1] + scaleBytes([0xE1]) + [1] + scaleBytes([0xD4]) +
            scaleBytes([0xA1]) + scaleBytes([0xB2]) + [1] +
            scaleBytes([0xC3]) + [1] + scaleBytes(Array("//test".utf8))
        var mismatched = source(role: 14, binding: 5, bytes: raw)
        let bindingIndex = try XCTUnwrap(mismatched.fields.firstIndex { $0.id == FieldID.bindingAccountID })
        mismatched.fields[bindingIndex].value = [0x44]
        XCTAssertThrowsError(try material(slots: [primary(role: 2), chain, mismatched]))

        let legacy = primary(role: 4)
        let wrongType = scaleBytes(Array("JSON".utf8)) + scaleBytes([0xA1]) +
            scaleBytes([0xB2]) + [1] + scaleBytes([0xC3]) +
            [1] + scaleBytes([0xD4]) + [0, 1] + scaleBytes(Array("//test".utf8))
        XCTAssertThrowsError(try Proof.verify(material(slots: [
            legacy, source(role: 10, binding: 2, bytes: wrongType, format: 2)
        ])))
    }

    private func primary(role: UInt8) -> Codec.Slot {
        var fields: [Codec.Field] = [
            field(FieldID.publicKey, [0xB2]), field(FieldID.privateKey, [0xA1]),
            field(FieldID.nonce, [0xC3]), field(FieldID.seed, [0xD4]),
            field(FieldID.derivationPath, Array("//test".utf8)),
            field(FieldID.accountIDOrAddress, role == 3 ? Array(repeating: 0, count: 33) : [0x33]),
            field(FieldID.sourceRecipe, [role == 4 ? 2 : 0])
        ]
        if role != 3 {
            fields.append(field(FieldID.entropy, [0xE1]))
        }
        if [1, 4, 5].contains(role) {
            fields.append(field(FieldID.cryptoType, [1]))
        }
        if role == 5 {
            fields.append(field(FieldID.chainName, []))
            fields.append(field(FieldID.initializedOrFavorite, [1]))
        }
        if role == 3 {
            fields.removeAll { $0.id == FieldID.nonce || $0.id == FieldID.derivationPath }
            fields.removeAll { $0.id == FieldID.seed }
            fields.append(field(FieldID.seed, Array("seed".utf8)))
            fields.append(field(FieldID.tonContractVersion, [2]))
            fields.append(field(FieldID.tonAddressEncoding, [1]))
        }
        if role == 4 {
            fields.removeAll { $0.id == FieldID.accountIDOrAddress }
            fields.append(field(FieldID.accountIDOrAddress, Array("5abc".utf8)))
            fields.removeAll { $0.id == FieldID.entropy }
        }
        return .init(role: role, key: role == 5 ? "chain-a" : "", fields: fields.sorted { $0.id < $1.id })
    }

    private func source(role: UInt8, binding: UInt8, bytes: [UInt8], format: UInt8 = 4) -> Codec.Slot {
        var fields = [
            field(FieldID.sourceRecipe, [0]), field(FieldID.sourcePlatform, [1]),
            field(FieldID.sourceSlotRole, [role]), field(FieldID.bindingKind, [binding]),
            field(FieldID.sourceFormat, [role == 14 ? 3 : format]),
            field(FieldID.sourceBytes, bytes)
        ]
        if binding == 5 {
            fields.append(field(FieldID.bindingChainID, Array("chain-a".utf8)))
            fields.append(field(FieldID.bindingAccountID, [0x33]))
        }
        return .init(role: 7, key: "0000", fields: fields.sorted { $0.id < $1.id })
    }

    private func field(_ id: UInt8, _ value: [UInt8]) -> Codec.Field {
        .init(id: id, value: value)
    }

    private func material(slots: [Codec.Slot]) throws -> Data {
        try Codec.encode(.init(selectedIndex: 0, wallets: [
            .init(
                portableID: (1 ... 16).map(UInt8.init),
                sourcePosition: 0,
                initialized: true,
                name: "Test",
                metadata: [],
                slots: slots.sorted { $0.role < $1.role || $0.role == $1.role && $0.key < $1.key }
            )
        ]))
    }

    private func scaleBytes(_ bytes: [UInt8]) -> [UInt8] {
        let count = bytes.count
        if count < 64 {
            return [UInt8(count << 2)] + bytes
        }
        let compact = count << 2 | 1
        return [UInt8(compact & 0xFF), UInt8((compact >> 8) & 0xFF)] + bytes
    }
}
