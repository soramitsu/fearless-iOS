import Foundation

enum AnalyticsPeriod: CaseIterable, Equatable {
    case week
    case month
    case year
    case all
}

extension AnalyticsPeriod {
    static let `default` = AnalyticsPeriod.week

    func title(for locale: Locale) -> String {
        switch self {
        case .week:
            return R.string.localizable
                .stakingAnalyticsPeriod7d(preferredLanguages: locale.rLanguages).uppercased()
        case .month:
            return R.string.localizable
                .stakingAnalyticsPeriod30d(preferredLanguages: locale.rLanguages).uppercased()
        case .year:
            return R.string.localizable
                .stakingAnalyticsPeriod1y(preferredLanguages: locale.rLanguages).uppercased()
        case .all:
            return R.string.localizable
                .stakingAnalyticsPeriodAll(preferredLanguages: locale.rLanguages).uppercased()
        }
    }

    func chartBarsCount(startDate: Date, endDate: Date, calendar: Calendar) -> Int {
        switch self {
        case .week:
            return 7
        case .month:
            return 30
        case .year:
            return 12
        case .all:
            let components = calendar.dateComponents([.month], from: startDate, to: endDate)
            return (components.month ?? 0) + 1
        }
    }

    func xAxisValues(dateRange: (Date, Date), locale: Locale) -> [String] {
        let template: String = {
            switch self {
            case .week, .month:
                return "MMM dd"
            case .year, .all:
                return "MMM yyyy"
            }
        }()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = template
        dateFormatter.locale = locale

        let firstDate = dateRange.0
        let lastDate = dateRange.1
        let middleTimestamp = (firstDate.timeIntervalSince1970 + lastDate.timeIntervalSince1970) / 2
        let middleDate = Date(timeIntervalSince1970: middleTimestamp)

        return [
            dateFormatter.string(from: firstDate),
            dateFormatter.string(from: middleDate),
            dateFormatter.string(from: lastDate)
        ]
    }
}

extension AnalyticsPeriod {
    func dateRangeTillNow(startDate: Date, endDate _: Date, calendar: Calendar) -> (Date, Date) {
        let now = Date()
        let endDate: Date = {
            switch self {
            case .week, .month:
                var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
                components.hour = 23
                components.minute = 59
                components.second = 59
                return calendar.date(from: components)!
            case .year, .all:
                let startOfMonth = calendar.date(
                    from: calendar.dateComponents([.year, .month], from: calendar.startOfDay(for: now))
                )!
                let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
                return endOfMonth
            }
        }()

        let startDate: Date = {
            switch self {
            case .week:
                return calendar.date(byAdding: DateComponents(day: -6, hour: -23, minute: -59), to: endDate)!
            case .month:
                return calendar.date(byAdding: DateComponents(day: -29, hour: -23, minute: -59), to: endDate)!
            case .year:
                return calendar.date(byAdding: DateComponents(year: -1, month: 1, day: 1), to: endDate)!
            case .all:
                return startDate
            }
        }()
        return (startDate, endDate)
    }
}
