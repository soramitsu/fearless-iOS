import XCTest
@testable import fearless
import IrohaCrypto

class FilterTests: XCTestCase {

    func testAccountFilterTest() {
        XCTAssertNoThrow(NSPredicate.filterAccountBy(networkType: .kusamaMain))
        XCTAssertNoThrow(NSPredicate.filterAccountBy(networkType: .polkadotMain))
        XCTAssertNoThrow(NSPredicate.filterAccountBy(networkType: .genericSubstrate))
    }
}
