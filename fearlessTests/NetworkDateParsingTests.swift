import SoraFoundation
import XCTest
@testable import fearless

final class NetworkDateParsingTests: XCTestCase {
    func testLiteralZuluInputFormatUsesUtcDespiteDeviceTimezone() throws {
        let original = NSTimeZone.default
        NSTimeZone.default = try XCTUnwrap(TimeZone(secondsFromGMT: 9 * 3600))
        defer { NSTimeZone.default = original }
        let formatter = DateFormatter.suibsquidInputDate.value(for: Locale(identifier: "th_TH"))
        XCTAssertEqual(formatter.string(from: Date(timeIntervalSince1970: 0)), "1970-01-01T00:00:00.000000Z")
        XCTAssertEqual(formatter.date(from: "1970-01-01T00:00:00.000000Z")?.timeIntervalSince1970, 0)
    }

    func testNetworkTimestampParsersPreserveExplicitOffset() throws {
        let date = try XCTUnwrap(
            DateFormatter.alchemyDate.value(for: Locale(identifier: "ar_SA"))
                .date(from: "2024-01-01T09:00:00.000+0900")
        )
        XCTAssertEqual(date.timeIntervalSince1970, 1_704_067_200)
        let squid = try XCTUnwrap(
            DateFormatter.giantsquidDate.value(for: Locale(identifier: "th_TH"))
                .date(from: "2024-01-01T00:00:00.000000+0000")
        )
        XCTAssertEqual(squid, date)
    }
}
