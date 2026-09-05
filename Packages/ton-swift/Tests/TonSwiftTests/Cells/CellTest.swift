import XCTest
@testable import TonSwift

final class CellTest: XCTestCase {
    
    func testCell() throws {
        // should construct
        let cell = Cell()
        XCTAssertEqual(cell.type, CellType.ordinary)
        XCTAssertEqual(cell.bits, Bitstring(data: .init(), unchecked:(offset: 0, length: 0)))
        XCTAssertEqual(cell.refs, [])
    }
    
    func testCellType() throws {
        // should match values in c++ code
        XCTAssertEqual(CellType.ordinary.rawValue, -1)
        XCTAssertEqual(CellType.prunedBranch.rawValue, 1)
        XCTAssertEqual(CellType.merkleProof.rawValue, 3)
        XCTAssertEqual(CellType.merkleUpdate.rawValue, 4)
    }
}
