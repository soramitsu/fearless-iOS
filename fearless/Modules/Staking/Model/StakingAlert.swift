import Foundation
import UIKit.UIImage
import SoraFoundation

enum StakingAlert {
    case nominatorNoValidators
    case nominatorLowStake(LocalizableResource<String>)
}

extension StakingAlert {
    var icon: UIImage? {
        switch self {
        case .nominatorNoValidators:
            return R.image.iconWarning()
        case .nominatorLowStake:
            return R.image.iconWarning()
        }
    }

    func title(for _: Locale) -> String {
        switch self {
        case .nominatorNoValidators:
            return "Change your validators." // TODO:
        case .nominatorLowStake:
            return "Bond more tokens."
        }
    }

    func description(for locale: Locale) -> String {
        switch self {
        case .nominatorNoValidators:
            return R.string.localizable
                .stakingNominatorStatusAlertNoValidators(preferredLanguages: locale.rLanguages)
        case let .nominatorLowStake(localizedString):
            return localizedString.value(for: locale)
        }
    }
}
