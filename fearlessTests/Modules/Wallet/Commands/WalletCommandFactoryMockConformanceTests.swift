import XCTest
@testable import fearless

// Guardrail test to prevent protocol drift between app and test mocks.
final class WalletCommandFactoryMockConformanceTests: XCTestCase {
    func testMockConformsToAppWalletCommandFactoryProtocol() {
        // Compile-time conformance check: this will fail to compile if the mock
        // stops conforming to fearless.WalletCommandFactoryProtocol.
        let _: fearless.WalletCommandFactoryProtocol = WalletCommandFactoryProtocolMock()
        XCTAssertTrue(true)
    }
}

