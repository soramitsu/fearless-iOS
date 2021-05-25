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
