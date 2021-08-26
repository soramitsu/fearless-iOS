import Foundation

enum AnalyticsPeriod: CaseIterable {
    case week
    case month
    case year
    case all
}

extension AnalyticsPeriod {
    static let `default` = AnalyticsPeriod.month

    func title(for _: Locale) -> String {
        // TODO:
        switch self {
        case .week:
            return "1w".uppercased()
        case .month:
            return "1m".uppercased()
        case .year:
            return "1y".uppercased()
        case .all:
            return "All"
        }
    }

    var chartBarsCount: Int {
        xAxisValues.count
    }

    var xAxisValues: [String] {
        switch self {
        case .week:
            return ["M", "T", "W", "T", "F", "S", "S"]
        case .month:
            return (0 ..< 30).map(\.description)
        case .year, .all: // TODO:
            return (1 ... 12).map { String($0) }
        }
    }
}

extension AnalyticsPeriod {
    var timestampInterval: (Int64, Int64) {
        let startDate: Date = {
            let interval: TimeInterval = {
                switch self {
                case .week:
                    return .secondsInDay * 7
                case .month:
                    return .secondsInDay * 31
                case .year, .all: // TODO:
                    return .secondsInDay * 31 * 12
                }
            }()
            return Date().addingTimeInterval(TimeInterval(-interval))
        }()

        let startTimestamp = Int64(startDate.timeIntervalSince1970)
        let endTimestamp = Int64(Date().timeIntervalSince1970)
        return (startTimestamp, endTimestamp)
    }
}
