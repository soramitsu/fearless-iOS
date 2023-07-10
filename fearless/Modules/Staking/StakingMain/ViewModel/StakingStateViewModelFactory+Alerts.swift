import Foundation
import SoraFoundation
import BigInt
import SSFModels

extension StakingStateViewModelFactory {
    func stakingAlertsForNominatorState(_ state: NominatorState) -> [StakingAlert] {
        [
            findInactiveAlert(state: state),
            findRedeemUnbondedAlert(commonData: state.commonData, ledgerInfo: state.ledgerInfo),
            findWaitingNextEraAlert(nominationStatus: state.status),
            findMinNominatorBondAlert(commonData: state.commonData, ledgerInfo: state.ledgerInfo)
        ].compactMap { $0 }
    }

    func stakingAlertsForValidatorState(_ state: ValidatorState) -> [StakingAlert] {
        [
            findRedeemUnbondedAlert(commonData: state.commonData, ledgerInfo: state.ledgerInfo)
        ].compactMap { $0 }
    }

    func stakingAlertsForBondedState(_ state: BondedState) -> [StakingAlert] {
        [
            findMinNominatorBondAlert(commonData: state.commonData, ledgerInfo: state.ledgerInfo),
            .bondedSetValidators,
            findRedeemUnbondedAlert(commonData: state.commonData, ledgerInfo: state.ledgerInfo)
        ].compactMap { $0 }
    }

    func stakingAlertsNoStashState(_: NoStashState) -> [StakingAlert] {
        []
    }

    func stakingAlertParachainState(_ state: ParachainState) -> [StakingAlert] {
        findCollatorLeavingAlert(state: state) + findLowStakeAlert(state: state) + findRedeemAlert(state: state)
    }

    private func findRedeemUnbondedAlert(
        commonData: StakingStateCommonData,
        ledgerInfo: StakingLedger
    ) -> StakingAlert? {
        guard
            let chainAsset = commonData.chainAsset,
            let era = commonData.eraStakersInfo?.activeEra,
            let precision = commonData.chainAsset?.assetDisplayInfo.assetPrecision,
            let redeemable = Decimal.fromSubstrateAmount(
                ledgerInfo.redeemable(inEra: era),
                precision: precision
            ),
            redeemable > 0
        else { return nil }

        let redeemableAmount = getBalanceViewModelFactory(for: chainAsset).amountFromValue(redeemable, usageCase: .listCrypto)
        let localizedString = LocalizableResource<String> { locale in
            redeemableAmount.value(for: locale)
        }
        return .redeemUnbonded(localizedString)
    }

    private func findMinNominatorBondAlert(
        commonData: StakingStateCommonData,
        ledgerInfo: StakingLedger
    ) -> StakingAlert? {
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
            )
        else {
            return nil
        }
        let minActiveAmount = getBalanceViewModelFactory(for: chainAsset).amountFromValue(minActiveDecimal, usageCase: .listCrypto)
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
                )
            else {
                return nil
            }
            let minActiveAmount = getBalanceViewModelFactory(for: chainAsset).amountFromValue(minActiveDecimal, usageCase: .listCrypto)
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

    private func findCollatorLeavingAlert(state: ParachainState) -> [StakingAlert] {
        let delegations = state.delegationInfos
        if let delegations = delegations {
            return delegations.compactMap { delegation in
                if case .leaving = delegation.collator.metadata?.status, let name = delegation.collator.identity?.name {
                    return .collatorLeaving(collatorName: name, delegation: delegation)
                }
                return nil
            }
        }
        return []
    }

    private func findLowStakeAlert(state: ParachainState) -> [StakingAlert] {
        guard let chainAsset = state.commonData.chainAsset,
              let accountId = try? state.commonData.address?.toAccountId(using: chainAsset.chain.chainFormat),
              let bottomDelegations = state.bottomDelegations,
              let topDelegations = state.topDelegations,
              let delegationInfos = state.delegationInfos else {
            return []
        }

        return bottomDelegations.compactMap { collatorBottomDelegations in
            if let delegation = collatorBottomDelegations.value.delegations.first(where: { $0.owner == accountId }),
               let minTopDelegationAmount =
               topDelegations[collatorBottomDelegations.key]?.delegations.compactMap({ delegation in
                   delegation.amount
               }).min() {
                let minTopDecimal = Decimal.fromSubstrateAmount(
                    minTopDelegationAmount,
                    precision: Int16(chainAsset.asset.precision)
                ) ?? 0.0
                let ownAmountDecimal = Decimal.fromSubstrateAmount(
                    delegation.amount,
                    precision: Int16(chainAsset.asset.precision)
                ) ?? 0.0
                let difference = (minTopDecimal - ownAmountDecimal) * 1.1

                if let collator = delegationInfos.first(where: { delegationInfo in
                    delegationInfo.collator.address == collatorBottomDelegations.key
                })?.collator {
                    return .collatorLowStake(
                        amount: difference.stringWithPointSeparator,
                        delegation: ParachainStakingDelegationInfo(
                            delegation: delegation,
                            collator: collator
                        )
                    )
                }
                return nil
            }
            return nil
        }
    }

    private func findRedeemAlert(state: ParachainState) -> [StakingAlert] {
        guard let chainAsset = state.commonData.chainAsset,
              let accountId = try? state.commonData.address?.toAccountId(using: chainAsset.chain.chainFormat),
              let delegationInfos = state.delegationInfos,
              let requests = state.requests,
              let round = state.round else {
            return []
        }

        return requests.compactMap { requestsByCollatorAddress in
            let ownOutdatedRequests = requestsByCollatorAddress.value
                .filter { $0.delegator == accountId }
                .filter { $0.whenExecutable <= round.current }

            let amount: BigUInt = ownOutdatedRequests.compactMap { ownRequest in
                var amount = BigUInt.zero
                if case let .revoke(revokeAmount) = ownRequest.action {
                    amount += revokeAmount
                }

                if case let .decrease(decreaseAmount) = ownRequest.action {
                    amount += decreaseAmount
                }

                return amount
            }.reduce(BigUInt.zero, +)

            if amount > BigUInt.zero,
               let delegationInfo = delegationInfos.first(where: { $0.collator.address == requestsByCollatorAddress.key }) {
                return .parachainRedeemUnbonded(delegation: delegationInfo)
            }

            return nil
        }
    }
}
