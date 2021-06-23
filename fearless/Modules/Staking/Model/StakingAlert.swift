import Foundation
import UIKit.UIImage
import SoraFoundation

enum StakingAlert {
    case bondedSetValidators
    case nominatorChangeValidators
    case nominatorLowStake(LocalizableResource<String>)
    case electionPeriod
    case redeemUnbonded(LocalizableResource<String>)
}

extension StakingAlert {
    var hasAssociatedAction: Bool {
        switch self {
        case .nominatorLowStake, .nominatorChangeValidators, .redeemUnbonded, .bondedSetValidators:
            return true
        case .electionPeriod:
            return false
        }
    }

    var icon: UIImage? {
        switch self {
        case .nominatorChangeValidators:
            return R.image.iconWarning()
        case .nominatorLowStake:
            return R.image.iconWarning()
        case .electionPeriod:
            return R.image.iconPending()
        case .redeemUnbonded:
            return R.image.iconWarning()
        case .bondedSetValidators:
            return R.image.iconWarning()
        }
    }

    func title(for locale: Locale) -> String {
        switch self {
        case .nominatorChangeValidators:
            return R.string.localizable.stakingChangeYourValidators(preferredLanguages: locale.rLanguages)
        case .nominatorLowStake:
            return R.string.localizable.stakingBondMoreTokens(preferredLanguages: locale.rLanguages)
        case .electionPeriod:
            return R.string.localizable.stakingActionsUnavailable(preferredLanguages: locale.rLanguages)
        case .redeemUnbonded:
            return R.string.localizable.stakingRedeemUnbondedTokens(preferredLanguages: locale.rLanguages)
        case .bondedSetValidators:
            return R.string.localizable.stakingSetValidatorsTitle(preferredLanguages: locale.rLanguages)
        }
    }

    func description(for locale: Locale) -> String {
        switch self {
        case .nominatorChangeValidators:
            return R.string.localizable
                .stakingNominatorStatusAlertNoValidators(preferredLanguages: locale.rLanguages)
        case let .nominatorLowStake(localizedString):
            return localizedString.value(for: locale)
        case .electionPeriod:
            return R.string.localizable
                .stakingNetworkIsElectingValidators(preferredLanguages: locale.rLanguages)
        case let .redeemUnbonded(localizedString):
            return localizedString.value(for: locale)
        case .bondedSetValidators:
            return R.string.localizable.stakingSetValidatorsMessage(preferredLanguages: locale.rLanguages)
        }
    }
}
