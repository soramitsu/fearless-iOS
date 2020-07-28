import XCTest
@testable import fearless

class RTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAllReferenceValid() {
        XCTAssertNoThrow(try R.validate())
    }
}
