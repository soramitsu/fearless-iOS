@testable import fearless
import Foundation
import SSFUtils
import TonSwift
import XCTest

final class IOSPortableWatchIdentityProofTests: XCTestCase {
    private typealias Codec = IOSPortableWalletSemanticMaterial
    private typealias FieldID = IOSPortableWalletSemanticMaterial.FieldID

    func testDerivesPresentSubstrateEVMAndTONPublicIdentities() throws {
        let substrate = (1 ... 32).map { UInt8($0) }
        let evm = try XCTUnwrap(Data(hex:
            "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"))
        let ton = Data(repeating: 7, count: 32)
        let rawTon = Data([0]) + (try TonAddressCodec.v4R2AccountHash(publicKey: ton))
        let approvedChainID = String(repeating: "a", count: 64)
        let watches = [
            watch(0, [
                field(FieldID.publicKey, substrate), field(FieldID.accountIDOrAddress, substrate),
                field(FieldID.cryptoType, [2]), field(FieldID.watchEcosystem, [1])
            ]),
            watch(1, [
                field(FieldID.publicKey, Array(evm)),
                field(FieldID.accountIDOrAddress, Array(try evm.ethereumAddressFromPublicKey())),
                field(FieldID.watchEcosystem, [2])
            ]),
            watch(2, [
                field(FieldID.publicKey, Array(ton)), field(FieldID.accountIDOrAddress, Array(rawTon)),
                field(FieldID.tonContractVersion, [2]), field(FieldID.tonAddressEncoding, [1]),
                field(FieldID.watchEcosystem, [3])
            ]),
            watch(3, [
                field(FieldID.publicKey, substrate), field(FieldID.accountIDOrAddress, substrate),
                field(FieldID.cryptoType, [2]), field(FieldID.watchEcosystem, [4]),
                field(FieldID.watchChainID, Array(approvedChainID.utf8))
            ])
        ]
        XCTAssertEqual(try IOSPortableWatchIdentityProof.verify(
            encode(watches), approvedSubstrateGenesisIDs: [approvedChainID]
        ), 4)
    }

    func testChainWatchRequiresFrozenCanonicalSubstrateInventory() throws {
        let publicKey = (1 ... 32).map { UInt8($0) }
        let chainID = String(repeating: "a", count: 64)
        let chain = watch(0, [
            field(FieldID.publicKey, publicKey), field(FieldID.accountIDOrAddress, publicKey),
            field(FieldID.cryptoType, [2]), field(FieldID.watchEcosystem, [4]),
            field(FieldID.watchChainID, Array(chainID.utf8))
        ])
        let encoded = try encode([chain])
        XCTAssertThrowsError(try IOSPortableWatchIdentityProof.verify(encoded))
        XCTAssertThrowsError(try IOSPortableWatchIdentityProof.verify(
            encoded, approvedSubstrateGenesisIDs: [chainID.uppercased()]
        ))
        XCTAssertEqual(try IOSPortableWatchIdentityProof.verify(
            encoded, approvedSubstrateGenesisIDs: [chainID]
        ), 1)
        XCTAssertThrowsError(try IOSPortableWalletReceiveInstallPlan.prepare(
            encoded, approvedSubstrateGenesisIDs: []
        ))
        var plan = try IOSPortableWalletReceiveInstallPlan.prepare(
            encoded, approvedSubstrateGenesisIDs: [chainID]
        )
        defer { plan.clearSecrets() }
        XCTAssertTrue(plan.blockers.contains(.unprovenWatchIdentities(1)))
        XCTAssertTrue(plan.blockers.contains(.transactionalInstallerUnavailable))
    }

    func testRejectsMismatchedAddressDuplicateIdentityAndMixedCustody() throws {
        let evm = try XCTUnwrap(Data(hex:
            "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"))
        let address = Array(try evm.ethereumAddressFromPublicKey())
        let valid = watch(0, [
            field(FieldID.publicKey, Array(evm)), field(FieldID.accountIDOrAddress, address),
            field(FieldID.watchEcosystem, [2])
        ])
        var wrongAddress = address
        wrongAddress[0] ^= 1
        let mismatched = watch(0, [
            field(FieldID.publicKey, Array(evm)), field(FieldID.accountIDOrAddress, wrongAddress),
            field(FieldID.watchEcosystem, [2])
        ])
        let duplicate = watch(1, valid.fields)
        let shortAddress = watch(0, [
            field(FieldID.accountIDOrAddress, [9]), field(FieldID.watchEcosystem, [2])
        ])
        let signed = Codec.Slot(role: Codec.Role.evmRoot, key: "", fields: [
            field(FieldID.publicKey, [1]), field(FieldID.privateKey, [2]),
            field(FieldID.accountIDOrAddress, [3]), field(FieldID.sourceRecipe, [0])
        ])
        for candidate in [[mismatched], [shortAddress], [valid, duplicate], [signed, valid]] {
            XCTAssertThrowsError(try IOSPortableWatchIdentityProof.verify(encode(candidate))) {
                XCTAssertEqual($0 as? IOSPortableWatchIdentityProof.ProofError, .invalidWatchIdentity)
            }
        }
        XCTAssertThrowsError(try IOSPortableWalletReceiveInstallPlan.prepare(
            encode([shortAddress]), approvedSubstrateGenesisIDs: []
        )) {
            XCTAssertEqual($0 as? IOSPortableWatchIdentityProof.ProofError, .invalidWatchIdentity)
        }
        let addressOnly = watch(0, [
            field(FieldID.accountIDOrAddress, address), field(FieldID.watchEcosystem, [2])
        ])
        XCTAssertEqual(try IOSPortableWatchIdentityProof.verify(encode([addressOnly])), 1)
    }

    func testLegacyTONJSONMustBindV4R2PublicKeyAndWorkchain() throws {
        let publicKey = Data(repeating: 7, count: 32)
        let hash = try TonAddressCodec.v4R2AccountHash(publicKey: publicKey)
        let address = try JSONEncoder().encode(TonSwift.Address(workchain: 0, hash: hash))
        let valid = watch(0, [
            field(FieldID.publicKey, Array(publicKey)),
            field(FieldID.accountIDOrAddress, Array(address)),
            field(FieldID.tonContractVersion, [2]), field(FieldID.tonAddressEncoding, [2]),
            field(FieldID.watchEcosystem, [3])
        ])
        XCTAssertEqual(try IOSPortableWatchIdentityProof.verify(encode([valid])), 1)

        let wrongWorkchain = watch(0, [
            field(FieldID.publicKey, Array(publicKey)),
            field(FieldID.accountIDOrAddress, Array(try JSONEncoder().encode(
                TonSwift.Address(workchain: 1, hash: hash)
            ))),
            field(FieldID.tonContractVersion, [2]), field(FieldID.tonAddressEncoding, [2]),
            field(FieldID.watchEcosystem, [3])
        ])
        XCTAssertThrowsError(try IOSPortableWatchIdentityProof.verify(encode([wrongWorkchain]))) {
            XCTAssertEqual($0 as? IOSPortableWatchIdentityProof.ProofError, .invalidWatchIdentity)
        }
    }

    private func encode(_ slots: [Codec.Slot]) throws -> Data {
        let wallet = Codec.Wallet(
            portableID: Array(1 ... 16).map { UInt8($0) }, sourcePosition: 0,
            initialized: true, name: "Watch", metadata: [], slots: slots
        )
        return try Codec.encode(.init(selectedIndex: 0, wallets: [wallet]))
    }

    private func watch(_ index: Int, _ fields: [Codec.Field]) -> Codec.Slot {
        Codec.Slot(role: Codec.Role.watchIdentity, key: String(format: "%04x", index), fields: fields)
    }

    private func field(_ id: UInt8, _ value: [UInt8]) -> Codec.Field {
        Codec.Field(id: id, value: value)
    }
}
