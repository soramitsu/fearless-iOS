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
            return ["1", "7", "15", "22", "31"]
        case .year, .all: // TODO:
            return (1 ... 12).map { String($0) }
        }
    }
}

extension AnalyticsPeriod {
    func timestampInterval(periodDelta: Int) -> (Int64, Int64) {
        let tillDate: Date = {
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
            return Date().addingTimeInterval(interval * Double(periodDelta))
        }()

        let calendar = Calendar(identifier: .iso8601)
        let dateComponent: Calendar.Component = {
            switch self {
            case .week:
                return .weekOfYear
            case .month:
                return .month
            case .year, .all:
                return .year
            }
        }()
        guard let interval = calendar.dateInterval(of: dateComponent, for: tillDate) else { return (0, 0) }
        let startTimestamp = Int64(interval.start.timeIntervalSince1970)
        let endTimestamp = Int64(interval.end.timeIntervalSince1970)
        return (startTimestamp, endTimestamp)
    }
}
