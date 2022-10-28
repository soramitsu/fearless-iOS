import Foundation
import UIKit

final class AddressCopiedEvent: ApplicationStatusAlertEvent {
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
            .applicationStatusViewCopiedTitle(preferredLanguages: locale?.rLanguages)
    }

    var descriptionText: String {
        R.string.localizable
            .applicationStatusViewCopiedDescription(preferredLanguages: locale?.rLanguages)
    }

    init(locale: Locale?) {
        self.locale = locale
    }
}
