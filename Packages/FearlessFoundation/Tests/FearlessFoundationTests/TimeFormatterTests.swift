import XCTest
@testable import FearlessFoundation

final class TimeFormatterTests: XCTestCase {
    func testMinuteSecondFormatter_whenIntervalHasMinutesAndSeconds_thenPadsComponents() throws {
        let formatter = MinuteSecondFormatter()

        XCTAssertEqual(try formatter.string(from: 65), "01:05")
    }

    func testHourMinuteFormatter_whenIntervalHasHoursAndMinutes_thenPadsComponents() throws {
        let formatter = HourMinuteFormatter()

        XCTAssertEqual(try formatter.string(from: 3_661), "01:01")
    }

    func testTotalTimeFormatter_whenIntervalHasHoursMinutesAndSeconds_thenPadsComponents() throws {
        let formatter = TotalTimeFormatter()

        XCTAssertEqual(try formatter.string(from: 3_661), "01:01:01")
    }
}
