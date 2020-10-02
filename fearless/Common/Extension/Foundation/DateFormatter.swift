import Foundation
import SoraFoundation

extension DateFormatter {
    static var history: LocalizableResource<DateFormatter> {
        LocalizableResource { locale in
            let format = DateFormatter.dateFormat(fromTemplate: "ddMMyyyyHHmmss", options: 0, locale: locale)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = format
            dateFormatter.locale = locale
            return dateFormatter
        }
    }
}
