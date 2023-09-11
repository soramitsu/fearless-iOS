import UIKit

final class CommonCopiedEvent: ApplicationStatusAlertEvent {
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
            .commonCopied(preferredLanguages: locale?.rLanguages)
    }

    var descriptionText: String {
        ""
    }

    init(locale: Locale?) {
        self.locale = locale
    }
}
