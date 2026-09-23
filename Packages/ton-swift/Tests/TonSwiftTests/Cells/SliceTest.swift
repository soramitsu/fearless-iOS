import XCTest
@testable import TonSwift

final class SliceTest: XCTestCase {
    
    func testSlice() throws {
        // should read uints from slice
        for _ in 0..<1000 {
            let a = UInt64.random(in: 0..<10000000)
            let b = UInt64.random(in: 0..<10000000)
            let builder = Builder()
            try builder.store(uint: a, bits: 48)
            try builder.store(uint: b, bits: 48)
            
            let bits = builder.bitstring()
            let slice = try Cell(bits: bits).beginParse()
            XCTAssertEqual(try slice.preloadUint(bits: 48), a)
            XCTAssertEqual(try slice.loadUint(bits: 48), a)
            XCTAssertEqual(try slice.preloadUint(bits: 48), b)
            XCTAssertEqual(try slice.loadUint(bits: 48), b)

            let bits2 = builder.bitstring()
            let slice2 = Slice(bits: bits2)
            XCTAssertEqual(try slice2.preloadUint(bits: 48), a)
            XCTAssertEqual(try slice2.loadUint(bits: 48), a)
            XCTAssertEqual(try slice2.preloadUint(bits: 48), b)
            XCTAssertEqual(try slice2.loadUint(bits: 48), b)

            // TODO: - create tests for int, varUint, varInt, coins, address
        }
    }

}
