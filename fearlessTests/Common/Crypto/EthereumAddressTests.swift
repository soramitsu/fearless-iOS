import XCTest
@testable import fearless

class EthereumAddressTests: XCTestCase {
    func testAddressFromPublicKey() {
        do {
            let pubKey = try Data(
                hexStringSSF: "6e145ccef1033dea239875dd00dfb4fee6e3348b84985c92f103444683bae07b83b5c38e5e2b0c8529d7fa3f64d46daa1ece2d9ac14cab9477d042c84c32ccd0"
            )

            let expectedAddress = "001d3f1ef827552ae1114027bd3ecf1f086ba0f9"

            let actualAddress = try pubKey.ethereumAddressFromPublicKey().toHex()

            XCTAssertEqual(expectedAddress, actualAddress)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSubstrateAliases_whenConvertedFromHexAndBlocks_thenReturnExpectedValues() {
        let substrateHex = String(repeating: "11", count: SubstrateConstants.accountIdLength)
        let ethereumHex = "0x" + String(repeating: "22", count: EthereumConstants.accountIdLength)
        let prefixedSubstrateHex = "0x" + String(repeating: "33", count: SubstrateConstants.accountIdLength)
        let ethereumLengthWithoutPrefix = String(repeating: "44", count: EthereumConstants.accountIdLength)

        XCTAssertEqual(
            AccountId.matchHex(substrateHex),
            Data(repeating: 0x11, count: SubstrateConstants.accountIdLength)
        )
        XCTAssertEqual(
            AccountId.matchHex(ethereumHex),
            Data(repeating: 0x22, count: EthereumConstants.accountIdLength)
        )
        XCTAssertNil(AccountId.matchHex(prefixedSubstrateHex))
        XCTAssertNil(AccountId.matchHex(ethereumLengthWithoutPrefix))
        XCTAssertNil(AccountId.matchHex("not-hex"))

        XCTAssertEqual(BlockNumber(10).secondsTo(block: 15, blockDuration: 6000), 30)
        XCTAssertEqual(BlockNumber(10).secondsTo(block: 8, blockDuration: 6000), -12)
        XCTAssertEqual(BlockNumber(0x0102_0304).toHex(), "0x01020304")
        XCTAssertEqual(BlockNumber(1).toHex(), "0x00000001")
    }
}
