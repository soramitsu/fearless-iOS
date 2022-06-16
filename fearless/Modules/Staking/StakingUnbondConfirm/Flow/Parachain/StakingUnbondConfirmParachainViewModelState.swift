import Foundation
import BigInt
import FearlessUtils

final class StakingUnbondConfirmParachainViewModelState: StakingUnbondConfirmViewModelState {
    func validators(using locale: Locale) -> [DataValidating] {
        [
            dataValidatingFactory.canUnbond(amount: inputAmount, bonded: bonded, locale: locale),

            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.stateListener?.refreshFeeIfNeeded()
            }),

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, locale: locale)
        ]
    }

    var builderClosure: ExtrinsicBuilderClosure? {
        { [weak self] builder in
            guard let strongSelf = self,
                  let amount = strongSelf.inputAmount.toSubstrateAmount(precision: Int16(strongSelf.chainAsset.asset.precision)) else {
                throw CommonError.undefined
            }

            let unbondCall = strongSelf.callFactory.scheduleDelegatorBondLess(
                candidate: strongSelf.candidate.owner,
                amount: amount
            )

            return try builder.adding(call: unbondCall)
        }
    }

    var reuseIdentifier: String? {
        guard let amount = inputAmount.toSubstrateAmount(precision: Int16(chainAsset.asset.precision)) else {
            return nil
        }

        let unbondCall = callFactory.scheduleDelegatorBondLess(candidate: candidate.owner, amount: amount)
        return unbondCall.callName
    }

    var accountAddress: AccountAddress? {
        wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
    }

    var stateListener: StakingUnbondConfirmModelStateListener?

    func setStateListener(_ stateListener: StakingUnbondConfirmModelStateListener?) {
        self.stateListener = stateListener
    }

    let candidate: ParachainStakingCandidateInfo
    let delegation: ParachainStakingDelegation
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let dataValidatingFactory: StakingDataValidatingFactory
    let inputAmount: Decimal
    let callFactory: SubstrateCallFactoryProtocol = SubstrateCallFactory()

    var bonded: Decimal?
    var balance: Decimal?
    var minimalBalance: Decimal?
    var minNominatorBonded: Decimal?
    var fee: Decimal?

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactory,
        inputAmount: Decimal,
        candidate: ParachainStakingCandidateInfo,
        delegation: ParachainStakingDelegation
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.dataValidatingFactory = dataValidatingFactory
        self.inputAmount = inputAmount
        self.candidate = candidate
        self.delegation = delegation

        bonded = Decimal.fromSubstrateAmount(
            delegation.amount,
            precision: Int16(chainAsset.asset.precision)
        )
    }

    private func setupExtrinsicBuiler(
        _ builder: ExtrinsicBuilderProtocol,
        amount: Decimal,
        resettingRewardDestination: Bool,
        chilling: Bool
    ) throws -> ExtrinsicBuilderProtocol {
        guard let amountValue = amount.toSubstrateAmount(precision: Int16(chainAsset.asset.precision)) else {
            throw CommonError.undefined
        }

        var resultBuilder = builder

        if chilling {
            resultBuilder = try builder.adding(call: callFactory.chill())
        }

        resultBuilder = try resultBuilder.adding(call: callFactory.unbond(amount: amountValue))

        if resettingRewardDestination {
            resultBuilder = try resultBuilder.adding(call: callFactory.setPayee(for: .stash))
        }

        return resultBuilder
    }
}

extension StakingUnbondConfirmParachainViewModelState: StakingUnbondConfirmParachainStrategyOutput {
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

    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimalBalance):
            self.minimalBalance = Decimal.fromSubstrateAmount(
                minimalBalance,
                precision: Int16(chainAsset.asset.precision)
            )

            stateListener?.provideAssetViewModel()
            stateListener?.refreshFeeIfNeeded()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveMinBonded(result: Result<BigUInt?, Error>) {
        switch result {
        case let .success(minNominatorBonded):
            if let minNominatorBonded = minNominatorBonded {
                self.minNominatorBonded = Decimal.fromSubstrateAmount(
                    minNominatorBonded,
                    precision: Int16(chainAsset.asset.precision)
                )
            } else {
                self.minNominatorBonded = nil
            }

            stateListener?.refreshFeeIfNeeded()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didSubmitUnbonding(result: Result<String, Error>) {
        stateListener?.didSubmitUnbonding(result: result)
    }
}
