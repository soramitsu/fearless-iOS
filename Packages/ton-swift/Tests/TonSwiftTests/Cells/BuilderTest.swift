import XCTest
@testable import TonSwift

final class BuilderTest: XCTestCase {

    func testBuilder() throws {
        // should read uints from builder
        for _ in 0..<1000 {
            let a = UInt64.random(in: 0..<10000000)
            let b = UInt64.random(in: 0..<10000000)
            let builder = Builder()
            try builder.store(uint: a, bits: 48)
            try builder.store(uint: b, bits: 48)
            
            let bits = builder.bitstring()
            let reader = Slice(bits: bits)
            XCTAssertEqual(try reader.preloadUint(bits: 48), a)
            XCTAssertEqual(try reader.loadUint(bits: 48), a)
            XCTAssertEqual(try reader.preloadUint(bits: 48), b)
            XCTAssertEqual(try reader.loadUint(bits: 48), b)
        }
        
        // TODO: - create tests for int, varUint, varInt, coins, address, external address
    }
}
