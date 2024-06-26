import Foundation
import UIKit

enum ReplaceChainOption: CaseIterable {
    case create
    case `import`

    var icon: UIImage? {
        switch self {
        case .create:
            return R.image.iconAdd()
        case .import:
            return R.image.iconReplace()
        }
    }

    func localizableTitle(for locale: Locale) -> String {
        switch self {
        case .create:
            return R.string.localizable.createNewAccount(preferredLanguages: locale.rLanguages)
        case .import:
            return R.string.localizable.alreadyHaveAccount(preferredLanguages: locale.rLanguages)
        }
    }
}
