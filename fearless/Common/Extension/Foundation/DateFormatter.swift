import Foundation
import SoraFoundation

extension DateFormatter {
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
        LocalizableResource { _ in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = DateStringFormat.subsquid.rawValue
            return dateFormatter
        }
    }

    static var suibsquidInputDate: LocalizableResource<DateFormatter> {
        LocalizableResource { _ in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = DateStringFormat.subsquidInput.rawValue
            return dateFormatter
        }
    }

    static var alchemyDate: LocalizableResource<DateFormatter> {
        LocalizableResource { _ in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = DateStringFormat.alchemy.rawValue
            return dateFormatter
        }
    }
}
