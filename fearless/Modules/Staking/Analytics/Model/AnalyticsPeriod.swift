import Foundation

enum AnalyticsPeriod: CaseIterable {
    case weekly
    case monthly
    case yearly
}

extension AnalyticsPeriod {
    func title(for _: Locale) -> String {
        switch self {
        case .weekly:
            return "weekly".uppercased()
        case .monthly:
            return "monthly".uppercased()
        case .yearly:
            return "yearly".uppercased()
        }
    }

    var chartBarsCount: Int {
        xAxisValues.count
    }

    var xAxisValues: [String] {
        switch self {
        case .weekly:
            return ["M", "T", "W", "T", "F", "S", "S"]
        case .monthly:
            return (1 ... 31).map { String($0) }
        case .yearly:
            return (1 ... 12).map { String($0) }
        }
    }
}

extension AnalyticsPeriod {
    var timestampInterval: (Int64, Int64) {
        let now = Date()
        let calendar = Calendar.current
        switch self {
        case .weekly:
            var startOfWeekComponent = calendar.dateComponents([.year, .month, .day], from: now)
            startOfWeekComponent.day = 0
            let startOfWeekDate = calendar.date(from: startOfWeekComponent) ?? now
            let endOfWeekDate = calendar.date(byAdding: .day, value: 6, to: startOfWeekDate) ?? now

            let startOfWeekTimestamp = Int64(startOfWeekDate.timeIntervalSince1970)
            let endOfWeekTimestamp = Int64(endOfWeekDate.timeIntervalSince1970)
            return (startOfWeekTimestamp, endOfWeekTimestamp)
        case .monthly:
            var startOfMonthComponent = calendar.dateComponents([.year, .month], from: now)
            startOfMonthComponent.day = 1
            let startOfMonthDate = calendar.date(from: startOfMonthComponent) ?? now
            let endOfMonthDate = calendar.date(byAdding: .month, value: 1, to: startOfMonthDate) ?? now

            let startOfMonthTimestamp = Int64(startOfMonthDate.timeIntervalSince1970)
            let endOfMonthTimestamp = Int64(endOfMonthDate.timeIntervalSince1970)
            return (startOfMonthTimestamp, endOfMonthTimestamp)
        case .yearly:
            var startOfYearComponent = calendar.dateComponents([.year], from: now)
            startOfYearComponent.day = 1
            let startOfYearDate = calendar.date(from: startOfYearComponent) ?? now
            let endOfYearDate = calendar.date(byAdding: .year, value: 1, to: startOfYearDate) ?? now

            let startOfYearTimestamp = Int64(startOfYearDate.timeIntervalSince1970)
            let endOfYearTimestamp = Int64(endOfYearDate.timeIntervalSince1970)
            return (startOfYearTimestamp, endOfYearTimestamp)
        }
    }
}
