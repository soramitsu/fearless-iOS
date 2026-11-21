import XCTest
@testable import fearless

/// Nomis dates have a fixed format. The decoder's formatter followed the device's calendar and locale, so on a
/// device using the Japanese calendar "2024-01-02T…" parsed as the year 4042.
final class NomisJSONDecoderTests: XCTestCase {
    private struct Stamp: Decodable {
        let updated: Date
    }

    func testFormatterIgnoresTheDevicesCalendarAndLocale() throws {
        guard case let .formatted(formatter) = NomisJSONDecoder().dateDecodingStrategy else {
            return XCTFail("Nomis dates are decoded with a formatter")
        }

        XCTAssertEqual(formatter.locale.identifier, "en_US_POSIX")
        XCTAssertEqual(formatter.calendar.identifier, .gregorian)
    }

    func testDateDecodesToItsGregorianInstant() throws {
        let json = Data(#"{"updated":"2024-01-02T03:04:05.123456+0000"}"#.utf8)

        let stamp = try NomisJSONDecoder().decode(Stamp.self, from: json)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: stamp.updated)
        XCTAssertEqual([parts.year, parts.month, parts.day, parts.hour, parts.minute, parts.second], [2024, 1, 2, 3, 4, 5])
    }
}
