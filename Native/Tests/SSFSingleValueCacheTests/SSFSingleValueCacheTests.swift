import XCTest

@testable import SSFSingleValueCache

final class SSFSingleValueCacheTests: XCTestCase {
    func testAssembly() throws {
        let assembly = SingleValueCacheRepositoryFactoryDefault()
        XCTAssertNoThrow(try assembly.createSingleValueCacheRepository())
    }
}
