import Foundation

enum AnalyticsPeriod: CaseIterable {
    case custom
    case today
    case yesterday
    case thisWeek
    case lastMonth
    case thisYear
}

extension AnalyticsPeriod {
    func title(for _: Locale) -> String {
        switch self {
        case .custom:
            return "Custom"
        case .today:
            return "Today"
        case .yesterday:
            return "Yesterday"
        default:
            return "Other"
        }
    }
}

extension AnalyticsPeriod {
    var timestampInterval: (Int64, Int64) {
        switch self {
        case .thisWeek:
            let currentTimestamp = Int64(Date().timeIntervalSince1970)

            var dayComponent = DateComponents()
            dayComponent.day = -7
            let weekAgoDate = Calendar.current.date(byAdding: dayComponent, to: Date())!
            let weekAgoTimestamp = Int64(weekAgoDate.timeIntervalSince1970)
            return (weekAgoTimestamp, currentTimestamp)
        default:
            return (0, 0)
        }
    }

    var xLegendSymbols: [String] {
        switch self {
        case .thisWeek:
            return ["M", "T", "W", "T", "F", "S", "S"]
        default:
            return []
        }
    }
}
