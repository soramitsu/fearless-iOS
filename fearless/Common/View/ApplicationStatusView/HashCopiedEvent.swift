import Foundation
import UIKit

final class HashCopiedEvent: ApplicationStatusAlertEvent {
    let locale: Locale?
    var autoDismissing: Bool { true }
    var backgroundColor: UIColor {
        R.color.colorColdGreen() ?? .green
    }

    var image: UIImage? {
        R.image.iconCopy()
    }

    var titleText: String {
        R.string.localizable
            .applicationStatusViewHashCopiedTitle(preferredLanguages: locale?.rLanguages)
    }

    var descriptionText: String {
        R.string.localizable
            .applicationStatusViewHashCopiedDescription(preferredLanguages: locale?.rLanguages)
    }

    init(locale: Locale?) {
        self.locale = locale
    }
}
