import XCTest

@testable import SSFXCM

final class XcmJunctionTests: XCTestCase {
    func testIsParachain() {
        // arrange
        let junction = XcmJunction.parachain(0)

        // act
        let isParachain = junction.isParachain()

        // assert
        XCTAssertTrue(isParachain)
    }

    func testEncode() throws {
        // arrange
        let junction = XcmJunction.onlyChild

        // act
        let encodedData = try JSONEncoder().encode(junction)

        // assert
        XCTAssertEqual(encodedData, TestData.xcmJunctionData)
    }

    func testInitFromDecoder() throws {
        // act
        let junction = try JSONDecoder().decode(
            XcmJunction.self,
            from: TestData.decodedData ?? Data()
        )

        // assert
        XCTAssertTrue(junction.isParachain())
    }

    func testAccountKey20DecodesFromItsOwnKey() throws {
        // arrange: the key used to be looked up under "accountId32", so any Ethereum style
        // account in a location list failed the whole list.
        let key = (1 ... 20).map { "\"\($0)\"" }.joined(separator: ",")
        let json = Data("""
        {"accountKey20": {"network": {"polkadot": {}}, "key": [\(key)]}}
        """.utf8)

        // act
        let junction = try JSONDecoder().decode(XcmJunction.self, from: json)

        // assert
        guard case let .accountKey20(value) = junction else {
            return XCTFail("Expected an AccountKey20 junction, got \(junction)")
        }
        XCTAssertEqual(value.key, Data(1 ... 20))
        XCTAssertEqual(value.network, .polkadot)
    }

    func testAccountKey20ListDecodes() throws {
        // V3 and later have no `Any` network: a junction without a network holds `None`.
        let json = Data("""
        [{"parachain": 2004}, {"accountKey20": {"network": null, "key": ["7"]}}]
        """.utf8)

        let junctions = try JSONDecoder().decode([XcmJunction].self, from: json)

        XCTAssertEqual(junctions.count, 2)
        XCTAssertTrue(junctions[0].isParachain())
        XCTAssertEqual(junctions[1], .accountKey20(AccountId20Value(network: nil, key: Data([7]))))
    }

    func testEquatable() {
        // arrange
        let junction1 = XcmJunction.generalKey(Data())
        let junction2 = XcmJunction.generalKey(Data())

        // assert
        XCTAssertEqual(junction1, junction2)
    }
}

extension XcmJunctionTests {
    enum TestData {
        static let xcmJunctionData = """
        ["OnlyChild",null]
        """.data(using: .utf8)

        static let decodedData = """
        {"parachain": 42}
        """.data(using: .utf8)
    }
}
