import Foundation
import SoraFoundation

enum ApplicationStatusViewViewModel {
    case addressCopied(locale: Locale?)
    case connectionOffline(locale: Locale?)
    case connectionOnline(locale: Locale?)

    var autoDismissing: Bool {
        switch self {
        case .addressCopied, .connectionOnline:
            return true
        case .connectionOffline:
            return false
        }
    }

    var backgroundColor: UIColor? {
        switch self {
        case .addressCopied:
            return R.color.colorColdGreen()
        case .connectionOffline:
            return R.color.colorPink1()
        case .connectionOnline:
            return R.color.colorColdGreen()
        }
    }

    var image: UIImage? {
        switch self {
        case .addressCopied:
            return R.image.iconCopy()
        case .connectionOffline:
            return R.image.iconConnectionOffline()
        case .connectionOnline:
            return R.image.iconConnectionOnline()
        }
    }

    var titleText: String {
        switch self {
        case let .addressCopied(locale):
            return R.string.localizable
                .applicationStatusViewCopiedTitle(preferredLanguages: locale?.rLanguages)
        case let .connectionOffline(locale):
            return R.string.localizable
                .applicationStatusViewOfflineTitle(preferredLanguages: locale?.rLanguages)
        case let .connectionOnline(locale):
            return R.string.localizable
                .applicationStatusViewReconnectedTitle(preferredLanguages: locale?.rLanguages)
        }
    }

    var descriptionText: String {
        switch self {
        case let .addressCopied(locale):
            return R.string.localizable
                .applicationStatusViewCopiedDescription(preferredLanguages: locale?.rLanguages)
        case let .connectionOffline(locale):
            return R.string.localizable
                .applicationStatusViewOfflineDescription(preferredLanguages: locale?.rLanguages)
        case let .connectionOnline(locale):
            return R.string.localizable
                .applicationStatusViewReconnectedDescription(preferredLanguages: locale?.rLanguages)
        }
    }
}
