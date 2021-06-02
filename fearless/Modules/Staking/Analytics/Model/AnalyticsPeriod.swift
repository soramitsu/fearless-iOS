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
            return (0 ... 31).map { String($0) }
        case .yearly:
            return (0 ... 12).map { String($0) }
        }
    }
}

extension AnalyticsPeriod {
    var timestampInterval: (Int64, Int64) {
        switch self {
        case .weekly:
            let currentTimestamp = Int64(Date().timeIntervalSince1970)

            var dayComponent = DateComponents()
            dayComponent.day = -7
            let weekAgoDate = Calendar.current.date(byAdding: dayComponent, to: Date())!
            let weekAgoTimestamp = Int64(weekAgoDate.timeIntervalSince1970)
            return (weekAgoTimestamp, currentTimestamp)
        case .monthly:
            let currentTimestamp = Int64(Date().timeIntervalSince1970)

            var dayComponent = DateComponents()
            dayComponent.month = -1
            let weekAgoDate = Calendar.current.date(byAdding: dayComponent, to: Date())!
            let weekAgoTimestamp = Int64(weekAgoDate.timeIntervalSince1970)
            return (weekAgoTimestamp, currentTimestamp)
        case .yearly:
            let currentTimestamp = Int64(Date().timeIntervalSince1970)

            var dayComponent = DateComponents()
            dayComponent.year = -1
            let weekAgoDate = Calendar.current.date(byAdding: dayComponent, to: Date())!
            let weekAgoTimestamp = Int64(weekAgoDate.timeIntervalSince1970)
            return (weekAgoTimestamp, currentTimestamp)
        }
    }

    var xLegendSymbols: [String] {
        switch self {
        case .weekly:
            return ["M", "T", "W", "T", "F", "S", "S"]
        default:
            return []
        }
    }
}
