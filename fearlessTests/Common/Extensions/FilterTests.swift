import XCTest
@testable import fearless
import IrohaCrypto

class FilterTests: XCTestCase {

    func testAccountFilterTest() {
        XCTAssertNoThrow(NSPredicate.filterBy(networkType: .kusamaMain))
        XCTAssertNoThrow(NSPredicate.filterBy(networkType: .polkadotMain))
        XCTAssertNoThrow(NSPredicate.filterBy(networkType: .genericSubstrate))
    }
}
