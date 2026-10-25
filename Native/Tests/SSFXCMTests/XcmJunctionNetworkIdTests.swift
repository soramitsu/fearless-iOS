import SSFModels
import SSFUtils
import XCTest

@testable import SSFXCM

final class XcmJunctionNetworkIdTests: XCTestCase {
    func testEncode() throws {
        // arrange
        let networkId = XcmJunctionNetworkId.polkadot

        // act
        let encodedData = try JSONEncoder().encode(networkId)

        // assert
        XCTAssertEqual(encodedData, TestData.networkIdData)
    }

    func testEthereumIsAStructWithAChainId() throws {
        // V3 and later: `Ethereum { chain_id: u64 }`, not a unit variant.
        let encodedData = try JSONEncoder().encode(XcmJunctionNetworkId.ethereum(chainId: 1))

        XCTAssertEqual(
            String(decoding: encodedData, as: UTF8.self),
            #"["Ethereum",{"chain_id":"1"}]"#
        )
    }

    func testByGenesisHoldsTheGenesisHash() throws {
        let encodedData = try JSONEncoder().encode(XcmJunctionNetworkId.byGenesis(Data([0xAB, 1])))

        XCTAssertEqual(String(decoding: encodedData, as: UTF8.self), #"["ByGenesis",["171","1"]]"#)
    }

    func testFromEcosystem() {
        // Accounts on chains outside the relay networks carry no network.
        XCTAssertNil(XcmJunctionNetworkId.from(ecosystem: .ethereum, version: .V3))
        XCTAssertNil(XcmJunctionNetworkId.from(ecosystem: .unknown, version: .V3))

        for version in [XcmCallFactoryVersion.V3, .V4, .V5] {
            XCTAssertEqual(
                XcmJunctionNetworkId.from(ecosystem: .polkadot, version: version),
                .polkadot
            )
            XCTAssertEqual(XcmJunctionNetworkId.from(ecosystem: .kusama, version: version), .kusama)
        }
        XCTAssertEqual(XcmJunctionNetworkId.from(ecosystem: .westend, version: .V4), .westend)
        XCTAssertEqual(XcmJunctionNetworkId.from(ecosystem: .rococo, version: .V3), .rococo)
    }

    func testV5NamesWestendAndRococoByGenesis() throws {
        // V5 dropped the `Westend`, `Rococo` and `Wococo` variants.
        XCTAssertEqual(
            XcmJunctionNetworkId.from(ecosystem: .westend, version: .V5),
            try .byGenesis(Data(hexStringSSF: Chain.westend.genesisHash))
        )
        XCTAssertEqual(
            XcmJunctionNetworkId.from(ecosystem: .rococo, version: .V5),
            try .byGenesis(Data(hexStringSSF: Chain.rococo.genesisHash))
        )
    }

    func testAnEthereumChainIsNoLongerTakenForWestend() {
        let ethereum = ChainModel(
            rank: 0,
            disabled: false,
            chainId: "1",
            paraId: nil,
            name: "Ethereum",
            xcm: nil,
            nodes: [],
            addressPrefix: 0,
            icon: nil,
            options: [.ethereum],
            iosMinAppVersion: nil,
            identityChain: nil
        )

        XCTAssertEqual(ChainEcosystem.defineEcosystem(chain: ethereum), .ethereum)
    }
}

extension XcmJunctionNetworkIdTests {
    enum TestData {
        static let networkIdData = """
        ["Polkadot",null]
        """.data(using: .utf8)
    }
}
