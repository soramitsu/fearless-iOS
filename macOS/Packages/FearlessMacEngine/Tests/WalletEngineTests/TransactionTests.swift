import BigInt
import Foundation
import SSFModels
import SSFUtils
import WalletCore
import XCTest
@testable import WalletEngine

final class TransactionTests: XCTestCase {
    private func fixture(_ name: String, _ ext: String) throws -> Data {
        try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: name, withExtension: ext)))
    }

    func testAssetHubMetadataStorageAndSignedExtrinsicAgainstPolkadotJS() throws {
        struct Recording: Decodable {
            struct Entry: Decodable { let key, value: String }
            let specVersion, transactionVersion: UInt32
            let system, assets: Entry
        }
        let recording = try JSONDecoder().decode(Recording.self, from: fixture("storage", "json"))
        let metadata = try (fixture("asset-hub.scale", "deflate") as NSData).decompressed(using: .zlib) as Data
        let rt = try SubstrateRuntime(
            data: metadata,
            spec: recording.specVersion,
            transaction: recording.transactionVersion
        )
        let system = try Data(hexStringSSF: recording.system.key)
        let spec = try rt.storage("System", "Account", keys: [system.suffix(32)])
        XCTAssertEqual(spec.key, recording.system.key)
        let account = try rt.decode(Data(hexStringSSF: recording.system.value), type: spec.type)
        let funds = try Funds.system(account, minimum: rt.existentialDeposit)
        XCTAssertEqual(funds.total, 10_041_752_589)
        XCTAssertEqual(funds.transferable, funds.total)
        let asset = try Data(hexStringSSF: recording.assets.key)
        let path = try rt.storage(
            "Assets",
            "Account",
            keys: [Data(asset.dropFirst(48).prefix(4)), Data(asset.suffix(32))]
        )
        XCTAssertEqual(path.key, recording.assets.key)
        let holder = try rt.decode(Data(hexStringSSF: recording.assets.value), type: path.type)
        XCTAssertEqual(try SubstrateRuntime.number(holder["balance"]), 1_000_000_000_000)
        let liquid = try Funds.asset(
            holder,
            details: .dictionaryValue([
                "min_balance": .stringValue("10"),
                "supply": .stringValue("1000000000000"),
                "status": .arrayValue([.stringValue("Live"), .null])
            ]),
            frozen: nil,
            held: nil
        )
        XCTAssertEqual(liquid.transferable, liquid.total)
        let vector = try JSONDecoder().decode([String: String].self, from: fixture("extrinsic", "json"))
        let id = try ChainID(String(XCTUnwrap(vector["genesis"]).dropFirst(2)))
        let sender = try Data(hexStringSSF: XCTUnwrap(vector["sender"]))
        let dest = Data(repeating: 2, count: 32)
        let block = try XCTUnwrap(vector["block"])
        let context = SubstrateRuntime.SigningContext(sender: sender, nonce: 7, height: 1234, block: block)
        let builder = try rt.builder(
            dest: dest,
            asset: .native(id),
            amount: 12345,
            keepAlive: true,
            context: context
        )
        XCTAssertEqual(try rt.payload(builder).toHex(), vector["payload"])
        let encoded = try rt.encode(
            builder,
            crypto: .ed25519,
            signature: Data(hexStringSSF: XCTUnwrap(vector["signature"]))
        )
        XCTAssertEqual(encoded.toHex(includePrefix: true), vector["encoded"])
        let token = try rt.builder(
            dest: dest,
            asset: AssetID(chainID: id, key: "asset:1984"),
            amount: 12345,
            keepAlive: true,
            context: context
        )
        let tokenPayload = try rt.payload(token)
        XCTAssertTrue(tokenPayload.toHex().hasPrefix("3209" + "011f00" + dest.toHex() + "e5c0"))
    }

    func testFrozenBalanceDiscountsReservedAndRespectsProviderReference() throws {
        let record = SSFUtils.JSON.dictionaryValue(["consumers": .stringValue("1"), "providers": .stringValue("1"),
                                                    "data": .dictionaryValue([
                                                        "free": .stringValue("120"),
                                                        "reserved": .stringValue("50"),
                                                        "frozen": .stringValue("70")
                                                    ])])
        let funds = try Funds.system(record, minimum: 30)
        XCTAssertEqual(funds.total, 170)
        XCTAssertEqual(funds.transferable, 90)
        XCTAssertEqual(try Funds.system(record, minimum: 5).transferable, 100)
    }

    func testLegacyAndTypedTransactionSignatures() throws {
        struct Case: Decodable {
            let type: Int
            let key, to, unsigned, signed: String
        }
        for vector in try JSONDecoder().decode([Case].self, from: fixture("evm-signatures", "json")) {
            let source = try WalletKeys.importSource(.seed(hex: vector.key, ecosystem: .evm, options: .standard))
            let typed = vector.type == 2
            let tx = try EVMTransfer(
                chain: 1,
                nonce: typed ? 0 : 9,
                gas: 21000,
                feeCap: typed ? 21_000_000_000 : 20_000_000_000,
                priority: typed ? 1_000_000_000 : nil,
                to: Data(hexStringSSF: vector.to),
                value: BigUInt(1_000_000_000_000_000_000),
                input: Data()
            )
            let unsigned = try tx.encode()
            XCTAssertEqual(unsigned.toHex(includePrefix: true), vector.unsigned)
            let signature = try XCTUnwrap(source.secret).sign(unsigned, ecosystem: .evm)
            XCTAssertEqual(try tx.encode(signature: signature).toHex(includePrefix: true), vector.signed)
        }
    }
}
