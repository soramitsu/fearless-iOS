import XCTest
@testable import fearless
import IrohaCrypto
import FearlessUtils

class ScaleExtrinsicTestsTests: XCTestCase {
    func testImmortal() throws {
        let expectedData = try Data(hexString: "0x2d02848ad2a3fba73321961cd5d1b8272aa95a21e75dd5b098fb36ed996961ac7b29310124f3150a8b0aa21712221a22baed55332461ab592e64f793cd1dedc26d98400c168e784fd57531a9d8ddd3fae731281d561346ee9a97f0646727ce0c404b5e80000c0004008ad2a3fba73321961cd5d1b8272aa95a21e75dd5b098fb36ed996961ac7b293102286bee")

        let decoder = try ScaleDecoder(data: expectedData)
        let extrinsic = try Extrinsic(scaleDecoder: decoder)

        let encoder = ScaleEncoder()
        try extrinsic.encode(scaleEncoder: encoder)

        let resultData = encoder.encode()

        XCTAssertEqual(resultData, expectedData)
    }
}
