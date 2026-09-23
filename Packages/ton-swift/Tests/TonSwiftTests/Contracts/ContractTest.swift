import XCTest
@testable import TonSwift

final class СontractAddressTest: XCTestCase {
    
    func testСontractAddress() throws {
        // should resolve address correctly
        
        let stateInit = StateInit(
            code: try Builder().store(uint: 1, bits: 8).endCell(),
            data: try Builder().store(uint: 2, bits: 8).endCell()
        )
        let addr = try OpaqueContract(workchain: 0, stateInit: stateInit).address()
        XCTAssertEqual(addr, try Address.parse("EQCSY_vTjwGrlvTvkfwhinJ60T2oiwgGn3U7Tpw24kupIhHz"))
    }
    
}
