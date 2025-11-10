import XCTest
@testable import fearless

class EthereumAddressTests: XCTestCase {
    func testAddressFromPublicKey() {
        do {
            let pubKey = try Data(
                hexString: "6e145ccef1033dea239875dd00dfb4fee6e3348b84985c92f103444683bae07b83b5c38e5e2b0c8529d7fa3f64d46daa1ece2d9ac14cab9477d042c84c32ccd0"
            )

            let expectedAddress = "001d3f1ef827552ae1114027bd3ecf1f086ba0f9"

            let actualAddress = try pubKey.ethereumAddressFromPublicKey().toHex()

            XCTAssertEqual(expectedAddress, actualAddress)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
