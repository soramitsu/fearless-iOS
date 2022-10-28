import Foundation
import UIKit

final class ConnectionOnlineEvent: ApplicationStatusAlertEvent {
    let locale: Locale?

    var autoDismissing: Bool { true }

    var backgroundColor: UIColor {
        R.color.colorColdGreen() ?? .green
    }

    var image: UIImage? {
        R.image.iconConnectionOnline()
    }

    var titleText: String {
        R.string.localizable
            .applicationStatusViewReconnectedTitle(preferredLanguages: locale?.rLanguages)
    }

    var descriptionText: String {
        R.string.localizable
            .applicationStatusViewReconnectedDescription(preferredLanguages: locale?.rLanguages)
    }

    init(locale: Locale?) {
        self.locale = locale
    }
}
