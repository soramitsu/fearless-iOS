import Foundation
import BigInt
import SSFUtils

final class StakingUnbondConfirmPoolViewModelState: StakingUnbondConfirmViewModelState {
    var stateListener: StakingUnbondConfirmModelStateListener?
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let dataValidatingFactory: StakingDataValidatingFactory
    let inputAmount: Decimal
    private let callFactory: SubstrateCallFactoryProtocol
    private(set) var bonded: Decimal?
    private(set) var balance: Decimal?
    private(set) var minimalBalance: Decimal?
    private(set) var minNominatorBonded: Decimal?
    private(set) var fee: Decimal?

    var builderClosure: ExtrinsicBuilderClosure? {
        guard
            let amount = inputAmount.toSubstrateAmount(precision: Int16(chainAsset.asset.precision)),
            let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId
        else {
            return nil
        }

        let unbondCall = callFactory.poolUnbond(accountId: accountId, amount: amount)

        return { builder in
            try builder.adding(call: unbondCall)
        }
    }

    var builderClosureOld: ExtrinsicBuilderClosure? {
        guard
            let amount = inputAmount.toSubstrateAmount(precision: Int16(chainAsset.asset.precision)),
            let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId
        else {
            return nil
        }

        let unbondCall = callFactory.poolUnbondOld(accountId: accountId, amount: amount)

        return { builder in
            try builder.adding(call: unbondCall)
        }
    }

    var reuseIdentifier: String? {
        guard
            let amount = StakingConstants.maxAmount.toSubstrateAmount(
                precision: Int16(chainAsset.asset.precision)
            ),
            let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId
        else {
            return nil
        }

        let unbondCall = callFactory.poolUnbond(accountId: accountId, amount: amount)

        return unbondCall.callName
    }

    var accountAddress: AccountAddress? {
        wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
    }

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactory,
        inputAmount: Decimal,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.dataValidatingFactory = dataValidatingFactory
        self.inputAmount = inputAmount
        self.callFactory = callFactory
    }

    func setStateListener(_ stateListener: StakingUnbondConfirmModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using locale: Locale) -> [DataValidating] {
        [
            dataValidatingFactory.canUnbond(amount: inputAmount, bonded: bonded, locale: locale),

            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.stateListener?.refreshFeeIfNeeded()
            }),

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, locale: locale)
        ]
    }
}

extension StakingUnbondConfirmPoolViewModelState: StakingUnbondConfirmPoolStrategyOutput {
    func didReceive(stakeInfo: StakingPoolMember?) {
        if let bonded = stakeInfo?.points {
            self.bonded = Decimal.fromSubstrateAmount(bonded, precision: Int16(chainAsset.asset.precision))

            stateListener?.provideAssetViewModel()
        }
    }

    func didReceive(error: Error) {
        stateListener?.didReceiveError(error: error)
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let accountInfo = accountInfo {
                balance = Decimal.fromSubstrateAmount(
                    accountInfo.data.stakingAvailable,
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
            stateListener?.didReceiveFeeError()
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
