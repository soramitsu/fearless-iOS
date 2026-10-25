import XCTest
@testable import fearless
import IrohaCrypto

class FilterTests: XCTestCase {

    func testAccountFilterTest() {
        XCTAssertNoThrow(NSPredicate.filterAccountBy(networkType: fearless.SNAddressType.kusamaMain))
        XCTAssertNoThrow(NSPredicate.filterAccountBy(networkType: fearless.SNAddressType.polkadotMain))
        XCTAssertNoThrow(NSPredicate.filterAccountBy(networkType: fearless.SNAddressType.genericSubstrate))
    }
}
