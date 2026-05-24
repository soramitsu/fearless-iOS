import XCTest
@testable import FearlessFoundation

final class CompoundDateFormatterTests: XCTestCase {
    func testString_whenDateIsToday_thenUsesTodayTitleAndFormatterLocale() throws {
        let formatter = makeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")

        let value = formatter.string(from: makeDate(year: 2026, month: 5, day: 23))

        XCTAssertEqual(value, "today-ja_JP")
    }

    func testString_whenDateIsYesterday_thenUsesYesterdayTitle() throws {
        let formatter = makeFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let value = formatter.string(from: makeDate(year: 2026, month: 5, day: 22))

        XCTAssertEqual(value, "yesterday-en_US_POSIX")
    }

    func testString_whenDateIsThisYear_thenUsesThisYearFormatter() throws {
        let formatter = makeFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let value = formatter.string(from: makeDate(year: 2026, month: 3, day: 10))

        XCTAssertEqual(value, "Mar 10")
    }

    func testString_whenNoItemMatches_thenUsesDefaultFormat() throws {
        let formatter = makeFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let value = formatter.string(from: makeDate(year: 2025, month: 12, day: 31))

        XCTAssertEqual(value, "2025-12-31")
    }

    private func makeFormatter() -> CompoundDateFormatter {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let builder = CompoundDateFormatterBuilder(
            baseDate: makeDate(year: 2026, month: 5, day: 23, file: #filePath, line: #line),
            calendar: calendar
        )

        return builder
            .withToday(title: LocalizableResource { "today-\($0.identifier)" })
            .withYesterday(title: LocalizableResource { "yesterday-\($0.identifier)" })
            .withThisYear(dateFormatter: LocalizableResource { locale in
                let formatter = DateFormatter()
                formatter.calendar = calendar
                formatter.locale = locale
                formatter.timeZone = calendar.timeZone
                formatter.dateFormat = "MMM d"
                return formatter
            })
            .build(defaultFormat: "yyyy-MM-dd")
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day

        guard let date = components.date else {
            XCTFail("Failed to build test date", file: file, line: line)
            return Date(timeIntervalSince1970: 0)
        }

        return date
    }
}
