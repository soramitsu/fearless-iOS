import Foundation
import SoraFoundation

extension StakingStateViewModelFactory {
    func stakingAlertsForNominatorState(_ state: NominatorState) -> [StakingAlert] {
        switch state.status {
        case .active:
            guard
                let era = state.commonData.eraStakersInfo?.era,
                let precision = state.commonData.chain?.addressType.precision,
                let redeemable = Decimal.fromSubstrateAmount(
                    state.ledgerInfo.redeemable(inEra: era),
                    precision: precision
                ),
                redeemable > 0,
                let redeemableAmount = balanceViewModelFactory?.amountFromValue(redeemable)
            else { return [] }

            let localizedString = LocalizableResource<String> { locale in
                redeemableAmount.value(for: locale)
            }
            return [.redeemUnbonded(localizedString)]
        case .inactive:
            guard let minimalStake = state.commonData.minimalStake else {
                return []
            }
            if state.ledgerInfo.active < minimalStake {
                guard
                    let chain = state.commonData.chain,
                    let minimalStakeDecimal = Decimal.fromSubstrateAmount(
                        minimalStake,
                        precision: chain.addressType.precision
                    ),
                    let minimalStakeAmount = balanceViewModelFactory?.amountFromValue(minimalStakeDecimal)
                else {
                    return []
                }
                let localizedString = LocalizableResource<String> { locale in
                    R.string.localizable
                        .stakingInactiveCurrentMinimalStake(
                            minimalStakeAmount.value(for: locale),
                            preferredLanguages: locale.rLanguages
                        )
                }
                return [.nominatorLowStake(localizedString)]
            } else {
                return [.nominatorNoValidators]
            }
        case .waiting:
            return []
        case .election:
            return [.electionPeriod]
        case .undefined:
            return []
        }
    }

    func stakingAlertsForValidatorState(_ state: ValidatorState) -> [StakingAlert] {
        switch state.status {
        case .active:
            guard
                let era = state.commonData.eraStakersInfo?.era,
                let precision = state.commonData.chain?.addressType.precision,
                let redeemable = Decimal.fromSubstrateAmount(
                    state.ledgerInfo.redeemable(inEra: era),
                    precision: precision
                ),
                redeemable > 0,
                let redeemableAmount = balanceViewModelFactory?.amountFromValue(redeemable)
            else { return [] }

            let localizedString = LocalizableResource<String> { locale in
                redeemableAmount.value(for: locale)
            }
            return [.redeemUnbonded(localizedString)]
        case .inactive:
            return []
        case .election:
            return [.electionPeriod]
        case .undefined:
            return []
        }
    }

    func stakingAlertsForBondedState(_ state: BondedState) -> [StakingAlert] {
        switch state.commonData.electionStatus {
        case .open:
            return [.electionPeriod]
        case .none, .close:
            guard
                let era = state.commonData.eraStakersInfo?.era,
                let precision = state.commonData.chain?.addressType.precision,
                let redeemable = Decimal.fromSubstrateAmount(
                    state.ledgerInfo.redeemable(inEra: era),
                    precision: precision
                ),
                redeemable > 0,
                let redeemableAmount = balanceViewModelFactory?.amountFromValue(redeemable)
            else { return [] }

            let localizedString = LocalizableResource<String> { locale in
                redeemableAmount.value(for: locale)
            }
            return [.redeemUnbonded(localizedString)]
        }
    }

    func stakingAlertsNoStashState(_ state: NoStashState) -> [StakingAlert] {
        switch state.commonData.electionStatus {
        case .open:
            return [.electionPeriod]
        case .none, .close:
            return []
        }
    }
}
