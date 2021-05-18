import Foundation
import UIKit.UIImage
import SoraFoundation

enum StakingAlert {
    case nominatorNoValidators
    case nominatorLowStake(LocalizableResource<String>)
    case electionPeriod
}

extension StakingAlert {
    var hasAssociatedAction: Bool {
        switch self {
        case .nominatorLowStake, .nominatorNoValidators:
            return true
        case .electionPeriod:
            return false
        }
    }

    var icon: UIImage? {
        switch self {
        case .nominatorNoValidators:
            return R.image.iconWarning()
        case .nominatorLowStake:
            return R.image.iconWarning()
        case .electionPeriod:
            return R.image.iconPending()
        }
    }

    func title(for locale: Locale) -> String {
        switch self {
        case .nominatorNoValidators:
            return R.string.localizable.stakingChangeYourValidators(preferredLanguages: locale.rLanguages)
        case .nominatorLowStake:
            return R.string.localizable.stakingBondMoreTokens(preferredLanguages: locale.rLanguages)
        case .electionPeriod:
            return R.string.localizable.stakingActionsUnavailable(preferredLanguages: locale.rLanguages)
        }
    }

    func description(for locale: Locale) -> String {
        switch self {
        case .nominatorNoValidators:
            return R.string.localizable
                .stakingNominatorStatusAlertNoValidators(preferredLanguages: locale.rLanguages)
        case let .nominatorLowStake(localizedString):
            return localizedString.value(for: locale)
        case .electionPeriod:
            return R.string.localizable
                .stakingNetworkIsElectingValidators(preferredLanguages: locale.rLanguages)
        }
    }
}
