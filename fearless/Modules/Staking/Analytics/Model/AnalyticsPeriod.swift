import Foundation

enum AnalyticsPeriod: CaseIterable {
    case week
    case month
    case year
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
        }
    }

    func chartBarsCount() -> Int {
        switch self {
        case .week:
            return 7
        case .month:
            return 30
        case .year:
            return 12
        }
    }

    func xAxisValues(dates: [Date]) -> [String] {
        let template: String = {
            switch self {
            case .week, .month:
                return "MMM dd"
            case .year:
                return "MMM yyyy"
            }
        }()
        let format = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: nil)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format

        guard
            let firstDate = dates.first,
            let lastDate = dates.last
        else { return [] }
        let middleDate = dates[dates.count / 2]

        var result = (0 ..< chartBarsCount()).map { _ in "" }
        result[0] = dateFormatter.string(from: firstDate)
        result[result.count / 2] = dateFormatter.string(from: middleDate)
        result[result.count - 1] = dateFormatter.string(from: lastDate)
        return result
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
                case .year:
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
