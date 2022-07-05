import Foundation
import SoraFoundation
import BigInt

extension StakingStateViewModelFactory {
    func stakingAlertsForNominatorState(_ state: NominatorState) -> [StakingAlert] {
        [
            findInactiveAlert(state: state),
            findRedeemUnbondedAlert(commonData: state.commonData, ledgerInfo: state.ledgerInfo),
            findWaitingNextEraAlert(nominationStatus: state.status)
        ].compactMap { $0 }
    }

    func stakingAlertsForValidatorState(_ state: ValidatorState) -> [StakingAlert] {
        [
            findRedeemUnbondedAlert(commonData: state.commonData, ledgerInfo: state.ledgerInfo)
        ].compactMap { $0 }
    }

    func stakingAlertsForBondedState(_ state: BondedState) -> [StakingAlert] {
        [
            findMinNominatorBondAlert(state: state),
            .bondedSetValidators,
            findRedeemUnbondedAlert(commonData: state.commonData, ledgerInfo: state.ledgerInfo)
        ].compactMap { $0 }
    }

    func stakingAlertsNoStashState(_: NoStashState) -> [StakingAlert] {
        []
    }

    func stakingAlertParachainState(_ state: ParachainState) -> [StakingAlert] {
        [
            findCollatorLeavingAlert(delegations: state.delegationInfos),
            findLowStakeAlert(delegations: state.delegationInfos),
            findRedeemAlert(delegations: state.delegationInfos)
        ].compactMap { $0 }
    }

    private func findRedeemUnbondedAlert(
        commonData: StakingStateCommonData,
        ledgerInfo: StakingLedger
    ) -> StakingAlert? {
        guard
            let era = commonData.eraStakersInfo?.activeEra,
            let precision = commonData.chainAsset?.assetDisplayInfo.assetPrecision,
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

        guard let minStake = commonData.minStake else {
            return nil
        }

        guard ledgerInfo.active < minStake else {
            return nil
        }

        guard
            let chainAsset = commonData.chainAsset,
            let minActiveDecimal = Decimal.fromSubstrateAmount(
                minStake,
                precision: chainAsset.assetDisplayInfo.assetPrecision
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

        guard let minStake = commonData.minStake else {
            return nil
        }

        if ledgerInfo.active < minStake {
            guard
                let chainAsset = commonData.chainAsset,
                let minActiveDecimal = Decimal.fromSubstrateAmount(
                    minStake,
                    precision: chainAsset.assetDisplayInfo.assetPrecision
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
        } else if state.allValidatorsWithoutReward {
            return .nominatorAllOversubscribed
        } else {
            return .nominatorChangeValidators
        }
    }

    private func findWaitingNextEraAlert(nominationStatus: NominationViewStatus) -> StakingAlert? {
        if case .waiting = nominationStatus {
            return .waitingNextEra
        }
        return nil
    }

//    Parachain

    private func findCollatorLeavingAlert(state: ParachainState) -> StakingAlert? {
        let delegations = state.delegationInfos
        if let delegations = delegations, delegations.contains(where: { delegation in
            delegation.collator.metadata?.status == .leaving
        }) {
            return .collatorLeaving
        }
        return nil
    }

    private func findLowStakeAlert(state: ParachainState) -> StakingAlert? {
        guard let chainFormat = state.commonData.chainAsset?.chain.chainFormat,
              let accountId = try? state.commonData.address?.toAccountId(using: chainFormat) else {
            return nil
        }

        let delegations = state.bottomDelegations?.values.compactMap(\.delegations).reduce([], +)

        if delegations?.contains(where: { delegation in
            delegation.owner == accountId
        }) == true {
            return .collatorLowStake(LocalizableResource { _ in String() })
        }

        return nil
    }

    private func findRedeemAlert(state: ParachainState) -> StakingAlert? {
        let requests = state.requests
        let round = state.round
        let amount = requests?.filter { request in
            guard let currentEra = round?.current else {
                return false
            }

            return request.whenExecutable <= currentEra
        }.compactMap { request in
            var amount = BigUInt.zero
            if case let .revoke(revokeAmount) = request.action {
                amount += revokeAmount
            }

            if case let .decrease(decreaseAmount) = request.action {
                amount += decreaseAmount
            }

            return amount
        }.reduce(BigUInt.zero, +)

        if let amount = amount, amount > BigUInt.zero {
            return .parachainRedeemUnbonded
        }

        return nil
    }
}
