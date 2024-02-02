import Foundation
import SoraFoundation

extension TimeInterval {
    static let secondsInHour: TimeInterval = 3600
    static let secondsInDay: TimeInterval = 24 * secondsInHour
    static let secondsInWeek: TimeInterval = secondsInDay * 7
    static let secondsInMonth: TimeInterval = secondsInWeek * 30

    var milliseconds: Int { Int(1000 * self) }
    var seconds: TimeInterval { self / 1000 }
    var daysFromSeconds: Int { Int(self / Self.secondsInDay) }
    var hoursFromSeconds: Int { Int(self / Self.secondsInHour) }
    var intervalsInDay: Int { self > 0.0 ? Int(Self.secondsInDay / self) : 0 }

    func readableValue(locale: Locale) -> String {
        if daysFromSeconds > 0 {
            return R.string.localizable.commonDaysFormat(format: daysFromSeconds, preferredLanguages: locale.rLanguages)
        }

        return R.string.localizable.commonHoursFormat(format: hoursFromSeconds, preferredLanguages: locale.rLanguages)
    }

    func localizedReadableValue() -> LocalizableResource<String> {
        LocalizableResource { locale in
            if daysFromSeconds > 0 {
                return R.string.localizable.commonDaysFormat(format: daysFromSeconds, preferredLanguages: locale.rLanguages)
            }

            return R.string.localizable.commonHoursFormat(format: hoursFromSeconds, preferredLanguages: locale.rLanguages)
        }
    }
}
