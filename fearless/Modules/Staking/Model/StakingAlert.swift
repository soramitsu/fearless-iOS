import Foundation
import UIKit.UIImage
import SoraFoundation

enum StakingAlert {
    case bondedSetValidators
    case nominatorChangeValidators
    case nominatorLowStake(LocalizableResource<String>)
    case nominatorAllOversubscribed
    case redeemUnbonded(LocalizableResource<String>)
    case waitingNextEra

    case collatorLeaving
    case collatorLowStake(LocalizableResource<String>)
    case parachainRedeemUnbonded
}

extension StakingAlert {
    var hasAssociatedAction: Bool {
        switch self {
        case .nominatorLowStake, .nominatorChangeValidators, .redeemUnbonded, .bondedSetValidators,
             .nominatorAllOversubscribed, .collatorLeaving, .collatorLowStake, .parachainRedeemUnbonded:
            return true
        case .waitingNextEra:
            return false
        }
    }

    var icon: UIImage? {
        switch self {
        case .nominatorChangeValidators, .nominatorLowStake, .redeemUnbonded, .bondedSetValidators,
             .nominatorAllOversubscribed, .collatorLeaving, .collatorLowStake, .parachainRedeemUnbonded:
            return R.image.iconWarning()
        case .waitingNextEra:
            return R.image.iconPending()
        }
    }

    func title(for locale: Locale) -> String {
        switch self {
        case .nominatorChangeValidators, .nominatorAllOversubscribed:
            return R.string.localizable.stakingChangeYourValidators(preferredLanguages: locale.rLanguages)
        case .nominatorLowStake, .collatorLowStake:
            return R.string.localizable.stakingBondMoreTokens(preferredLanguages: locale.rLanguages)
        case .redeemUnbonded, .parachainRedeemUnbonded:
            return R.string.localizable.stakingRedeemUnbondedTokens(preferredLanguages: locale.rLanguages)
        case .bondedSetValidators:
            return R.string.localizable.stakingSetValidatorsTitle(preferredLanguages: locale.rLanguages)
        case .waitingNextEra:
            return R.string.localizable.stakingNominatorStatusAlertWaitingMessage(preferredLanguages: locale.rLanguages)
        case .collatorLeaving:
            return R.string.localizable.stakingLeavingCollators(preferredLanguages: locale.rLanguages)
        }
    }

    func description(for locale: Locale) -> String {
        switch self {
        case .nominatorChangeValidators:
            return R.string.localizable
                .stakingNominatorStatusAlertNoValidators(preferredLanguages: locale.rLanguages)
        case .nominatorAllOversubscribed:
            return R.string.localizable
                .stakingYourOversubscribedMessage(preferredLanguages: locale.rLanguages)
        case let .nominatorLowStake(localizedString):
            return localizedString.value(for: locale)
        case let .redeemUnbonded(localizedString):
            return localizedString.value(for: locale)
        case .bondedSetValidators:
            return R.string.localizable.stakingSetValidatorsMessage(preferredLanguages: locale.rLanguages)
        case .waitingNextEra:
            return R.string.localizable.stakingAlertStartNextEraMessage(preferredLanguages: locale.rLanguages)
        case .collatorLeaving:
            return R.string.localizable.stakingLeavingCollatorsDescription(preferredLanguages: locale.rLanguages)
        case let .collatorLowStake(localizedString):
            return localizedString.value(for: locale)
        case .parachainRedeemUnbonded:
            return String()
        }
    }
}
