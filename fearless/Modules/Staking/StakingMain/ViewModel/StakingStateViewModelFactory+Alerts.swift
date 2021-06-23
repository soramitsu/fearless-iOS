import Foundation
import SoraFoundation

extension StakingStateViewModelFactory {
    func stakingAlertsForNominatorState(_ state: NominatorState) -> [StakingAlert] {
        [
            findInactiveAlert(state: state),
            findElectionAlert(commonData: state.commonData),
            findRedeemUnbondedAlert(commonData: state.commonData, ledgerInfo: state.ledgerInfo)
        ].compactMap { $0 }
    }

    func stakingAlertsForValidatorState(_ state: ValidatorState) -> [StakingAlert] {
        [
            findElectionAlert(commonData: state.commonData),
            findRedeemUnbondedAlert(commonData: state.commonData, ledgerInfo: state.ledgerInfo)
        ].compactMap { $0 }
    }

    func stakingAlertsForBondedState(_ state: BondedState) -> [StakingAlert] {
        [
            findMinNominatorBondAlert(state: state),
            .bondedSetValidators,
            findElectionAlert(commonData: state.commonData),
            findRedeemUnbondedAlert(commonData: state.commonData, ledgerInfo: state.ledgerInfo)
        ].compactMap { $0 }
    }

    func stakingAlertsNoStashState(_ state: NoStashState) -> [StakingAlert] {
        [
            findElectionAlert(commonData: state.commonData)
        ].compactMap { $0 }
    }

    private func findElectionAlert(commonData: StakingStateCommonData) -> StakingAlert? {
        switch commonData.electionStatus {
        case .open:
            return .electionPeriod
        case .none, .close:
            return nil
        }
    }

    private func findRedeemUnbondedAlert(
        commonData: StakingStateCommonData,
        ledgerInfo: StakingLedger
    ) -> StakingAlert? {
        guard
            let era = commonData.eraStakersInfo?.era,
            let precision = commonData.chain?.addressType.precision,
            let redeemable = Decimal.fromSubstrateAmount(
                ledgerInfo.redeemable(inEra: era),
                precision: precision
            ),
            redeemable > 0,
            let redeemableAmount = balanceViewModelFactory?.amountFromValue(redeemable)
        else { return nil }

        let localizedString = LocalizableResource<String> { locale in
            redeemableAmount.value(for: locale)
        }
        return .redeemUnbonded(localizedString)
    }

    private func findMinNominatorBondAlert(state: BondedState) -> StakingAlert? {
        let commonData = state.commonData
        let ledgerInfo = state.ledgerInfo

        guard let minimalStake = commonData.minimalStake else {
            return nil
        }

        let minActive = commonData.minNominatorBond.map { max(minimalStake, $0) } ?? minimalStake

        guard ledgerInfo.active < minActive else {
            return nil
        }

        guard
            let chain = commonData.chain,
            let minActiveDecimal = Decimal.fromSubstrateAmount(
                minActive,
                precision: chain.addressType.precision
            ),
            let minActiveAmount = balanceViewModelFactory?.amountFromValue(minActiveDecimal)
        else {
            return nil
        }

        let localizedString = LocalizableResource<String> { locale in
            R.string.localizable.stakingInactiveCurrentMinimalStake(
                minActiveAmount.value(for: locale),
                preferredLanguages: locale.rLanguages
            )
        }

        return .nominatorLowStake(localizedString)
    }

    private func findInactiveAlert(state: NominatorState) -> StakingAlert? {
        guard case .inactive = state.status else { return nil }

        let commonData = state.commonData
        let ledgerInfo = state.ledgerInfo

        guard let minimalStake = commonData.minimalStake else {
            return nil
        }

        let minActive = commonData.minNominatorBond.map { max(minimalStake, $0) } ?? minimalStake

        if ledgerInfo.active < minActive {
            guard
                let chain = commonData.chain,
                let minActiveDecimal = Decimal.fromSubstrateAmount(
                    minActive,
                    precision: chain.addressType.precision
                ),
                let minActiveAmount = balanceViewModelFactory?.amountFromValue(minActiveDecimal)
            else {
                return nil
            }

            let localizedString = LocalizableResource<String> { locale in
                R.string.localizable.stakingInactiveCurrentMinimalStake(
                    minActiveAmount.value(for: locale),
                    preferredLanguages: locale.rLanguages
                )
            }
            return .nominatorLowStake(localizedString)
        } else {
            return .nominatorChangeValidators
        }
    }
}
