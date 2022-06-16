import Foundation
import BigInt

final class StakingUnbondSetupParachainViewModelState: StakingUnbondSetupViewModelState {
    var bonded: Decimal?
    var balance: Decimal?
    var inputAmount: Decimal?
    var bondingDuration: UInt32?
    var minimalBalance: Decimal?
    var fee: Decimal?
    var controller: ChainAccountResponse?

    var stateListener: StakingUnbondSetupModelStateListener?

    let delegation: ParachainStakingDelegation
    let candidate: ParachainStakingCandidateInfo
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let dataValidatingFactory: StakingDataValidatingFactory
    let callFactory: SubstrateCallFactoryProtocol = SubstrateCallFactory()

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactory,
        candidate: ParachainStakingCandidateInfo,
        delegation: ParachainStakingDelegation
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.dataValidatingFactory = dataValidatingFactory
        self.candidate = candidate
        self.delegation = delegation

        bonded = Decimal.fromSubstrateAmount(
            delegation.amount,
            precision: Int16(chainAsset.asset.precision)
        )
    }

    func setStateListener(_ stateListener: StakingUnbondSetupModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using locale: Locale) -> [DataValidating] {
        [
            dataValidatingFactory.canUnbond(amount: inputAmount, bonded: bonded, locale: locale),

            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.stateListener?.updateFeeIfNeeded()
            }),

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, locale: locale),

            dataValidatingFactory.stashIsNotKilledAfterUnbonding(
                amount: inputAmount,
                bonded: bonded,
                minimumAmount: minimalBalance,
                locale: locale
            )
        ]
    }

    func selectAmountPercentage(_ percentage: Float) {
        if let bonded = bonded {
            inputAmount = bonded * Decimal(Double(percentage))
            stateListener?.provideInputViewModel()
            stateListener?.provideAssetViewModel()
        }
    }

    func updateAmount(_ amount: Decimal) {
        inputAmount = amount
        stateListener?.provideAssetViewModel()

        if fee == nil {
            stateListener?.updateFeeIfNeeded()
        }
    }

    var builderClosure: ExtrinsicBuilderClosure? {
        guard
            let amount = StakingConstants.maxAmount.toSubstrateAmount(
                precision: Int16(chainAsset.asset.precision)
            ) else {
            return nil
        }

        let unbondCall = callFactory.scheduleDelegatorBondLess(candidate: candidate.owner, amount: amount)

        return { builder in
            try builder.adding(call: unbondCall)
        }
    }

    var confirmationFlow: StakingUnbondConfirmFlow? {
        guard let inputAmount = inputAmount else {
            return nil
        }

        return .parachain(
            candidate: candidate,
            delegation: delegation,
            amount: inputAmount
        )
    }
}

extension StakingUnbondSetupParachainViewModelState: StakingUnbondSetupParachainStrategyOutput {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let accountInfo = accountInfo {
                balance = Decimal.fromSubstrateAmount(
                    accountInfo.data.available,
                    precision: Int16(chainAsset.asset.precision)
                )
            } else {
                balance = nil
            }
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let fee = BigUInt(dispatchInfo.fee) {
                self.fee = Decimal.fromSubstrateAmount(fee, precision: Int16(chainAsset.asset.precision))
            }

            stateListener?.provideFeeViewModel()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveBondingDuration(result: Result<UInt32, Error>) {
        switch result {
        case let .success(bondingDuration):
            self.bondingDuration = bondingDuration
            stateListener?.provideBondingDuration()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimalBalance):
            self.minimalBalance = Decimal.fromSubstrateAmount(
                minimalBalance,
                precision: Int16(chainAsset.asset.precision)
            )
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }
}
