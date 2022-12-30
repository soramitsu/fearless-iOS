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

    case collatorLeaving(collatorName: String, delegation: ParachainStakingDelegationInfo)
    case collatorLowStake(amount: String, delegation: ParachainStakingDelegationInfo)
    case parachainRedeemUnbonded(delegation: ParachainStakingDelegationInfo)
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
        case .nominatorLowStake:
            return R.string.localizable.stakingBondMoreTokens(preferredLanguages: locale.rLanguages)
        case .redeemUnbonded:
            return R.string.localizable.stakingRedeemUnbondedTokens(preferredLanguages: locale.rLanguages)
        case .bondedSetValidators:
            return R.string.localizable.stakingSetValidatorsTitle(preferredLanguages: locale.rLanguages)
        case .waitingNextEra:
            return R.string.localizable.stakingNominatorStatusAlertWaitingMessage(preferredLanguages: locale.rLanguages)
        case let .collatorLeaving(collatorName, _):
            return R.string.localizable.stakingAlertLeavingCollatorTitle(
                collatorName,
                preferredLanguages: locale.rLanguages
            )
        case .collatorLowStake:
            return R.string.localizable.stakingAlertLowStakeTitle(preferredLanguages: locale.rLanguages)
        case .parachainRedeemUnbonded:
            return R.string.localizable.stakingAlertUnlockTitle(preferredLanguages: locale.rLanguages)
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
        case let .collatorLeaving(collatorName, _):
            return R.string.localizable.stakingAlertLeavingCollatorText(
                collatorName,
                preferredLanguages: locale.rLanguages
            )
        case let .collatorLowStake(amount, _):
            return R.string.localizable.stakingAlertLowStakeText(
                amount,
                preferredLanguages: locale.rLanguages
            )
        case .parachainRedeemUnbonded:
            return R.string.localizable.stakingAlertUnlockText(preferredLanguages: locale.rLanguages)
        }
    }
}
