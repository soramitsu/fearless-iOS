import UIKit
import XCTest
@testable import fearless

final class HexColorValidationTests: XCTestCase {
    func testOnlyCompleteSixDigitHexValuesAreAccepted() throws {
        for value in ["GGGGGG", "FFFFFG", "00xx00", "12345", "1234567"] {
            XCTAssertNil(HexColorConverter.hexStringToUIColor(hex: value))
        }
        XCTAssertNil(HexColorConverter.hexStringToUIColor(hex: nil))
        XCTAssertEqual(HexColorConverter.hexStringToUIColor(hex: " #ff0000\n"), UIColor.red)
        let black = try XCTUnwrap(HexColorConverter.hexStringToUIColor(hex: "000000"))
        var red: CGFloat = 1
        var green: CGFloat = 1
        var blue: CGFloat = 1
        var alpha: CGFloat = 0
        XCTAssertTrue(black.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        XCTAssertEqual([red, green, blue, alpha], [0, 0, 0, 1])
    }
}
