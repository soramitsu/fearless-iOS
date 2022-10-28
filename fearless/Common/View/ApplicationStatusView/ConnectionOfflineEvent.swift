import Foundation
import UIKit

final class ConnectionOfflineEvent: ApplicationStatusAlertEvent {
    let locale: Locale?

    var autoDismissing: Bool { false }

    var backgroundColor: UIColor {
        R.color.colorPink1() ?? .systemPink
    }

    var image: UIImage? {
        R.image.iconConnectionOffline()
    }

    var titleText: String {
        R.string.localizable
            .applicationStatusViewOfflineTitle(preferredLanguages: locale?.rLanguages)
    }

    var descriptionText: String {
        R.string.localizable
            .applicationStatusViewOfflineDescription(preferredLanguages: locale?.rLanguages)
    }

    init(locale: Locale?) {
        self.locale = locale
    }
}
