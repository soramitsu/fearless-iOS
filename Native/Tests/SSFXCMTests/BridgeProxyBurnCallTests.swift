import BigInt
import SSFModels
import SSFUtils
import XCTest

@testable import SSFXCM

final class BridgeProxyBurnCallTests: XCTestCase {
    func testBridgeProxyBurnCallInit() {
        // arrange
        let amount = BigUInt()
        let networkId: BridgeTypesGenericNetworkId = .evm(amount)
        let assetId = SoraAssetId(wrappedValue: "1")
        let recipient: BridgeTypesGenericAccount = .root

        // act
        let call = BridgeProxyBurnCall(
            networkId: networkId,
            assetId: assetId,
            recipient: recipient,
            amount: amount
        )

        // assert
        XCTAssertEqual(call.amount, amount)
        XCTAssertEqual(call.networkId, networkId)
        XCTAssertEqual(call.assetId, assetId)
        XCTAssertEqual(call.recipient, recipient)
    }

    func testBridgeTypesGenericNetworkIdInit() throws {
        // act
        let networkId = try BridgeTypesGenericNetworkId(from: TestData.chain)

        // assert
        XCTAssertEqual(networkId, .sub(.kusama))
    }

    func testBridgeTypesGenericNetworkIdEncode() throws {
        // arrange
        let networkId = try BridgeTypesGenericNetworkId(from: TestData.chain)

        // act
        let encodedData = try JSONEncoder().encode(networkId)

        // assert
        XCTAssertEqual(encodedData, TestData.genericNetworkIdData)
    }

    func testBridgeTypesSubNetworkIdInit() {
        // act
        let subNetworkId = BridgeTypesSubNetworkId(from: TestData.chain)

        // assert
        XCTAssertEqual(subNetworkId, .kusama)
    }

    func testEverySubNetworkComparesByItsCase() {
        let all: [BridgeTypesSubNetworkId] = [.mainnet, .kusama, .polkadot, .rococo, .liberland]

        for (index, lhs) in all.enumerated() {
            for (otherIndex, rhs) in all.enumerated() {
                XCTAssertEqual(lhs == rhs, index == otherIndex, "\(lhs) == \(rhs)")
            }
        }
        XCTAssertNotEqual(BridgeTypesGenericNetworkId.sub(.liberland), .sub(.kusama))
    }

    func testANetworkWithoutASoraBridgeIsRefused() {
        // `custom(0)` used to stand in for it, and no SORA runtime has such a variant.
        let westend = TestData.chain(id: Chain.westend.genesisHash)

        XCTAssertNil(BridgeTypesSubNetworkId(from: westend))
        XCTAssertThrowsError(try BridgeTypesGenericNetworkId(from: westend)) { error in
            XCTAssertEqual(
                "\(error)",
                "\(XcmError.unsupportedBridgeNetwork(chainId: Chain.westend.genesisHash))"
            )
        }
    }

    func testSubNetworksOfKnownChains() {
        XCTAssertEqual(
            BridgeTypesSubNetworkId(from: TestData.chain(id: Chain.soraMain.genesisHash)),
            .mainnet
        )
        XCTAssertEqual(
            BridgeTypesSubNetworkId(from: TestData.chain(id: Chain.liberland.genesisHash)),
            .liberland
        )
        XCTAssertEqual(
            BridgeTypesSubNetworkId(from: TestData.chain(id: Chain.polkadot.genesisHash)),
            .polkadot
        )
        // A parachain goes through the bridge of its relay network.
        XCTAssertEqual(
            BridgeTypesSubNetworkId(from: TestData.chain(
                id: "fc41b9bd8ef8fe53d58c7ea67c794c7ec9a73daf05e6d54b14ff6342c99ba64c",
                parentId: Chain.polkadot.genesisHash
            )),
            .polkadot
        )
    }

    func testEvmChainIdsAreParsedWithoutCrashing() throws {
        XCTAssertEqual(try BridgeTypesGenericNetworkId.evmChainId(from: "1"), 1)
        XCTAssertEqual(try BridgeTypesGenericNetworkId.evmChainId(from: "0x38"), 56)
        XCTAssertEqual(try BridgeTypesGenericNetworkId.evmChainId(from: "0X38"), 56)

        // `BigUInt(stringLiteral:)` force-unwrapped these and crashed the app.
        for invalid in [
            "",
            "0x",
            "ethereum",
            "0xZZ",
            "-1",
            "+1",
            "1.5",
            "0x1" + String(repeating: "0", count: 64),
        ] {
            XCTAssertThrowsError(
                try BridgeTypesGenericNetworkId.evmChainId(from: invalid),
                invalid
            ) { error in
                XCTAssertEqual("\(error)", "\(XcmError.invalidEvmChainId(invalid))")
            }
        }
    }

    func testAnEvmNetworkIsAnH256() throws {
        // SORA's `GenericNetworkId::EVM(H256)`: the chain id as 32 big-endian bytes.
        let encodedData = try JSONEncoder().encode(BridgeTypesGenericNetworkId.evm(0x38))

        let expectedBytes = Array(repeating: "\"0\"", count: 31) + ["\"56\""]
        XCTAssertEqual(
            String(decoding: encodedData, as: UTF8.self),
            "[\"EVM\",[" + expectedBytes.joined(separator: ",") + "]]"
        )
    }

    func testBridgeTypesSubNetworkIdEncode() throws {
        // arrange
        let subNetworkId = BridgeTypesSubNetworkId(from: TestData.chain)

        // act
        let encodedData = try JSONEncoder().encode(subNetworkId)

        // assert
        XCTAssertEqual(encodedData, TestData.subNetworkIdData)
    }

    func testBridgeTypesGenericAccountEncode() throws {
        // arrange
        let genericAccount = BridgeTypesGenericAccount.root

        // act
        let encodedData = try JSONEncoder().encode(genericAccount)

        // assert
        XCTAssertEqual(encodedData, TestData.genericAccountData)
    }

    func testSoraAssetIdInit() {
        // arrange
        let value = "1"

        // act
        let soraAssetId = SoraAssetId(wrappedValue: value)

        // assert
        XCTAssertNotNil(soraAssetId)
        XCTAssertEqual(soraAssetId.value, value)
    }

    func testSoraAssetIdInitFromDecoder() throws {
        // act
        let soraAssetId = try JSONDecoder().decode(
            SoraAssetId.self,
            from: TestData.soraAssetIdDecodeData ?? Data()
        )

        // assert
        XCTAssertEqual(
            soraAssetId.value,
            "0x6dfe7b6bad5bd5ddb86fa71d7b96b5d9febbefd7bd775ddfedce7d75bef67dcd9aeb76dddfcd9ae9cf757bb7b8d5feb5"
        )
    }

    func testSoraAssetIdEncode() throws {
        // arrange
        let soraAssetId = SoraAssetId(wrappedValue: TestData.hexString)

        // act
        let encodedData = try JSONEncoder().encode(soraAssetId)

        // assert
        XCTAssertEqual(encodedData, TestData.soraAssetIdData)
    }

    func testArrayCodableInit() {
        // arrange
        let value = "1"

        // act
        let arrayCodable = ArrayCodable(wrappedValue: value)

        // assert
        XCTAssertNotNil(arrayCodable)
        XCTAssertEqual(arrayCodable.wrappedValue, value)
    }

    func testArrayCodableInitFromDecoder() throws {
        // act
        let arrayCodable = try JSONDecoder().decode(
            ArrayCodable.self,
            from: TestData.arrayCodableData ?? Data()
        )

        // assert
        XCTAssertEqual(arrayCodable.wrappedValue, TestData.hexString)
    }

    func testArrayCodableEncode() throws {
        // arrange
        let arrayCodable = ArrayCodable(wrappedValue: TestData.hexString)

        // act
        let encodedData = try JSONEncoder().encode(arrayCodable)

        // assert
        XCTAssertEqual(encodedData, TestData.arrayCodableData)
    }
}

extension BridgeProxyBurnCallTests {
    enum TestData {
        static let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test")
            .appendingPathExtension("json")

        static let chain = ChainModel(
            rank: 1,
            disabled: false,
            chainId: "b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe",
            paraId: "1",
            name: "test",
            xcm: nil,
            nodes: Set([ChainNodeModel(url: TestData.url, name: "test", apikey: nil)]),
            addressPrefix: 1,
            icon: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )

        static func chain(id: String, parentId: String? = nil) -> ChainModel {
            ChainModel(
                rank: 1,
                disabled: false,
                chainId: id,
                parentId: parentId,
                paraId: parentId == nil ? nil : "2000",
                name: "test",
                xcm: nil,
                nodes: [],
                addressPrefix: 1,
                icon: nil,
                iosMinAppVersion: nil,
                identityChain: nil
            )
        }

        static let hexString = "0xbf57a61b1d24b6cde5a12f6779e9d13f7c59db72fc2a63bd382a6c91e7e41f61"

        static let genericNetworkIdData = """
        ["Sub",["Kusama",null]]
        """.data(using: .utf8)

        static let subNetworkIdData = """
        ["Kusama",null]
        """.data(using: .utf8)

        static let genericAccountData = """
        ["Root",null]
        """.data(using: .utf8)

        static let soraAssetIdData = """
        {"code":["191","87","166","27","29","36","182","205","229","161","47","103","121","233","209","63","124","89","219","114","252","42","99","189","56","42","108","145","231","228","31","97"]}
        """.data(using: .utf8)

        static let soraAssetIdDecodeData = """
        {"code": "bf57a61b1d24b6cde5a12f6779e9d13f7c59db72fc2a63bd382a6c91e7e41f61"}
        """.data(using: .utf8)

        static let arrayCodableData = """
        ["191","87","166","27","29","36","182","205","229","161","47","103","121","233","209","63","124","89","219","114","252","42","99","189","56","42","108","145","231","228","31","97"]
        """.data(using: .utf8)
    }
}
