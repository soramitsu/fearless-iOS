import XCTest
@testable import fearless

class AccountManagementTests: XCTestCase {
    func testAccountManagementSkipped() throws {
        throw XCTSkip("Legacy AccountManagement module no longer present; flows replaced by current wallet/account UI.")
    }
}
