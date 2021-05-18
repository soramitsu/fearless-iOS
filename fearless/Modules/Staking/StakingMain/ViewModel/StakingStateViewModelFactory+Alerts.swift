import Foundation
import SoraFoundation

extension StakingStateViewModelFactory {
    func stakingAlertsForNominatorState(_ state: NominatorState) -> [StakingAlert] {
        switch state.status {
        case .active:
            switch state.commonData.electionStatus {
            case .open:
                return [.electionPeriod]
            case .none, .close:
                return []
            }
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
        case .undefined:
            return []
        }
    }

    func stakingAlertsForValidatorState(_ state: ValidatorState) -> [StakingAlert] {
        switch state.commonData.electionStatus {
        case .open:
            return [.electionPeriod]
        case .none, .close:
            return []
        }
    }

    func stakingAlertsForBondedState(_ state: BondedState) -> [StakingAlert] {
        switch state.commonData.electionStatus {
        case .open:
            return [.electionPeriod]
        case .none, .close:
            return []
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
