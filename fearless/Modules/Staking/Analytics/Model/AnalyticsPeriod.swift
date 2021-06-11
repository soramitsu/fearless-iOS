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
        let calendar = Calendar(identifier: .iso8601)
        let dateComponent: Calendar.Component = {
            switch self {
            case .weekly:
                return .weekOfYear
            case .monthly:
                return .month
            case .yearly:
                return .year
            }
        }()
        guard let interval = calendar.dateInterval(of: dateComponent, for: now) else { return (0, 0) }
        let startTimestamp = Int64(interval.start.timeIntervalSince1970)
        let endTimestamp = Int64(interval.end.timeIntervalSince1970)
        return (startTimestamp, endTimestamp)
    }
}
