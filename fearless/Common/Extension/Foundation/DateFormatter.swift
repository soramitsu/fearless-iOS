import Foundation
import FearlessFoundation

private enum NetworkDateParsingConstants {
    static var locale: Locale { Locale(identifier: "en_US_POSIX") }
    static var timeZone: TimeZone { TimeZone(secondsFromGMT: 0)! }
}

extension DateFormatter {
    static var iso: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        df.timeZone = TimeZone(abbreviation: "UTC")
        return df
    }

    static var txHistory: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let format = DateFormatter.dateFormat(fromTemplate: "HHmm", options: 0, locale: locale)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = format
            dateFormatter.locale = locale
            return dateFormatter
        }
    }

    static var txDetails: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let format = DateFormatter.dateFormat(fromTemplate: "ddMMMyyyyHHmmss", options: 0, locale: locale)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = format
            dateFormatter.locale = locale
            return dateFormatter
        }
    }

    static var shortDate: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let format = DateFormatter.dateFormat(fromTemplate: "ddMMMyyyy", options: 0, locale: locale)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = format
            dateFormatter.locale = locale
            return dateFormatter
        }
    }

    static var sectionedDate: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let format = DateFormatter.dateFormat(fromTemplate: "MMMM dd", options: 0, locale: locale)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = format
            dateFormatter.locale = locale
            return dateFormatter
        }
    }

    static var giantsquidDate: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = DateStringFormat.subsquid.rawValue
            dateFormatter.locale = locale
            dateFormatter.timeZone = NetworkDateParsingConstants.timeZone
            return dateFormatter
        }
    }

    static var suibsquidInputDate: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = DateStringFormat.subsquidInput.rawValue
            dateFormatter.locale = locale
            dateFormatter.timeZone = NetworkDateParsingConstants.timeZone
            return dateFormatter
        }
    }

    static var alchemyDate: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = DateStringFormat.alchemy.rawValue
            dateFormatter.locale = locale
            dateFormatter.timeZone = NetworkDateParsingConstants.timeZone
            return dateFormatter
        }
    }

    static var connectionExpiry: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let format = DateFormatter.dateFormat(fromTemplate: "EEE, MMM d, yyyy", options: 0, locale: locale)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = format
            dateFormatter.locale = locale
            return dateFormatter
        }
    }

    static func networkTimestampInSeconds(
        from timestamp: String,
        using formatter: LocalizableResource<DateFormatter>
    ) -> Int64 {
        let date = formatter.value(for: NetworkDateParsingConstants.locale).date(from: timestamp)
        return Int64(date?.timeIntervalSince1970 ?? 0)
    }

    static func networkTimestampString(
        from timeIntervalSince1970: Int64,
        using formatter: LocalizableResource<DateFormatter>
    ) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timeIntervalSince1970))
        return formatter.value(for: NetworkDateParsingConstants.locale).string(from: date)
    }
}
