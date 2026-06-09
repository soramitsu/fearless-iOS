import XCTest
@testable import fearless

final class HexColorConverterTests: XCTestCase {
    func testHexStringToUIColor_whenHexIsNilOrMalformed_thenReturnsNil() {
        XCTAssertNil(HexColorConverter.hexStringToUIColor(hex: nil))
        XCTAssertNil(HexColorConverter.hexStringToUIColor(hex: "#12345"))
        XCTAssertNil(HexColorConverter.hexStringToUIColor(hex: "#1234567"))
        XCTAssertNil(HexColorConverter.hexStringToUIColor(hex: "#GGGGGG"))
    }

    func testHexStringToUIColor_whenHexHasHashAndWhitespace_thenParsesRGBComponents() throws {
        let color = try XCTUnwrap(HexColorConverter.hexStringToUIColor(hex: " \n#0A1B2C\t"))

        assertColor(color, red: 10, green: 27, blue: 44, alpha: 255)
    }

    func testUIColorToHex_whenConvertingColor_thenReturnsUppercaseRGBAndRGBAStrings() {
        let color = UIColor(
            red: CGFloat(10) / 255.0,
            green: CGFloat(27) / 255.0,
            blue: CGFloat(44) / 255.0,
            alpha: CGFloat(128) / 255.0
        )

        XCTAssertEqual(HexColorConverter.uiColorToHexRGB(color: color), "#0A1B2C")
        XCTAssertEqual(HexColorConverter.uiColorToHexRGBA(color: color), "#0A1B2C80")
    }

    private func assertColor(
        _ color: UIColor,
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var actualRed: CGFloat = 0
        var actualGreen: CGFloat = 0
        var actualBlue: CGFloat = 0
        var actualAlpha: CGFloat = 0

        XCTAssertTrue(
            color.getRed(&actualRed, green: &actualGreen, blue: &actualBlue, alpha: &actualAlpha),
            file: file,
            line: line
        )
        XCTAssertEqual(actualRed, red / 255.0, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualGreen, green / 255.0, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualBlue, blue / 255.0, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualAlpha, alpha / 255.0, accuracy: 0.001, file: file, line: line)
    }
}
