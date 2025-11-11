import XCTest
@testable import fearless
import IrohaCrypto

class FilterTests: XCTestCase {

    func testAccountFilterTest() {
        XCTAssertNoThrow(NSPredicate.filterAccountBy(networkType: SNAddressType.kusamaMain))
        XCTAssertNoThrow(NSPredicate.filterAccountBy(networkType: SNAddressType.polkadotMain))
        XCTAssertNoThrow(NSPredicate.filterAccountBy(networkType: SNAddressType.genericSubstrate))
    }
}
