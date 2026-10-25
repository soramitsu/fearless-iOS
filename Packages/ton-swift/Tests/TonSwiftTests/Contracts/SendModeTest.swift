import XCTest
@testable import TonSwift

final class SendModeTest: XCTestCase {

    func testSendModeEncoding() throws {
        XCTAssertEqual(SendMode().rawValue, 0);
        XCTAssertEqual(SendMode.walletDefault().rawValue, 3);
        XCTAssertEqual(SendMode(value: .sendRemainingBalance).rawValue, 128);
        XCTAssertEqual(SendMode(value: .sendRemainingBalanceAndDestroy).rawValue, 128+32);
        XCTAssertEqual(SendMode(value: .addInboundValue).rawValue, 64);
        XCTAssertEqual(SendMode(payMsgFees: true).rawValue, 1);
        XCTAssertEqual(SendMode(payMsgFees: true, ignoreErrors: true).rawValue, 3);
        XCTAssertEqual(SendMode(payMsgFees: true, ignoreErrors: true, value: .sendRemainingBalanceAndDestroy).rawValue, 3+128+32);
    }
}
