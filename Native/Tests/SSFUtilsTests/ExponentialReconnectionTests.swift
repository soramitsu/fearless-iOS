import XCTest

@testable import SSFUtils

final class ExponentialReconnectionTests: XCTestCase {
    func testTheDelayGrowsExponentially() throws {
        let strategy = ExponentialReconnection(multiplier: 0.5)

        for attempt in 0 ..< 5 {
            let delay = try XCTUnwrap(strategy.reconnectAfter(attempt: attempt))
            XCTAssertEqual(delay, 0.5 * exp(Double(attempt)), accuracy: 1e-9)
        }
    }

    func testWithoutABoundItNeverGivesUp() {
        // The socket keeps reconnecting; `SubstrateConnectionAutoBalance` relies on that.
        let strategy = ExponentialReconnection()

        XCTAssertNotNil(strategy.reconnectAfter(attempt: 50))
    }

    func testWithABoundItGivesUp() {
        let strategy = ExponentialReconnection(maxAttempts: 3)

        XCTAssertNotNil(strategy.reconnectAfter(attempt: 1))
        XCTAssertNotNil(strategy.reconnectAfter(attempt: 2))
        XCTAssertNil(strategy.reconnectAfter(attempt: 3))
        XCTAssertNil(strategy.reconnectAfter(attempt: 100))
    }
}
