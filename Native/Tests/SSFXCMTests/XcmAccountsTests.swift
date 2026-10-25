import BigInt
import SSFModels
import XCTest

@testable import SSFXCM

final class XcmAccountsTests: XCTestCase {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    func testAccountId32ValueInit() {
        // arrange
        let network: XcmJunctionNetworkId = .kusama
        let accountId: AccountId = Data()

        // act
        let accountValue = AccountId32Value(
            network: network,
            accountId: accountId
        )

        // assert
        XCTAssertEqual(accountValue.network, network)
        XCTAssertEqual(accountValue.accountId, accountId)
    }

    func testAccountId20ValueInit() {
        // arrange
        let network: XcmJunctionNetworkId = .kusama
        let key: AccountId = Data()

        // act
        let accountValue = AccountId20Value(
            network: network,
            key: key
        )

        // assert
        XCTAssertEqual(accountValue.network, network)
        XCTAssertEqual(accountValue.key, key)
    }

    func testAccountIndexValueInit() {
        // arrange
        let network: XcmJunctionNetworkId = .kusama
        let index: UInt64 = 0

        // act
        let accountValue = AccountIndexValue(
            network: network,
            index: index
        )

        // assert
        XCTAssertEqual(accountValue.network, network)
        XCTAssertEqual(accountValue.index, index)
    }

    func testANetworkIsEncodedAsSome() throws {
        let account = AccountId32Value(network: .polkadot, accountId: Data([1, 2]))

        XCTAssertEqual(
            try String(decoding: encoder.encode(account), as: UTF8.self),
            #"{"id":["1","2"],"network":["Polkadot",null]}"#
        )
    }

    func testNoNetworkIsEncodedAsNone() throws {
        // `Option<NetworkId>` needs the key with `null`; a missing key is no value at all.
        let accounts: [Encodable] = [
            AccountId32Value(network: nil, accountId: Data([1])),
            AccountId20Value(network: nil, key: Data([1])),
            AccountIndexValue(network: nil, index: 7),
        ]

        let json = try accounts.map { try String(decoding: encoder.encode($0), as: UTF8.self) }

        XCTAssertEqual(json, [
            #"{"id":["1"],"network":null}"#,
            #"{"key":["1"],"network":null}"#,
            #"{"index":"7","network":null}"#,
        ])
    }
}
