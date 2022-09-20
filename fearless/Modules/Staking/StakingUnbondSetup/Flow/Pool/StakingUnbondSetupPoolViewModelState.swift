import Foundation
import BigInt

final class StakingUnbondSetupPoolViewModelState: StakingUnbondSetupViewModelState {
    var stateListener: StakingUnbondSetupModelStateListener?
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    private(set) var bonded: Decimal?
    private(set) var balance: Decimal?
    private(set) var inputAmount: Decimal?
    private(set) var stakingDuration: StakingDuration?
    private(set) var minimalBalance: Decimal?
    private(set) var fee: Decimal?
    private let dataValidatingFactory: StakingDataValidatingFactory
    private let callFactory: SubstrateCallFactoryProtocol = SubstrateCallFactory()

    var builderClosure: ExtrinsicBuilderClosure? {
        guard
            let amount = StakingConstants.maxAmount.toSubstrateAmount(
                precision: Int16(chainAsset.asset.precision)
            ), let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return nil
        }

        let unbondCall = callFactory.poolUnbond(accountId: accountId, amount: amount)

        return { builder in
            try builder.adding(call: unbondCall)
        }
    }

    var confirmationFlow: StakingUnbondConfirmFlow? {
        guard let inputAmount = inputAmount else {
            return nil
        }

        return .pool(amount: inputAmount)
    }

    var accountAddress: AccountAddress? {
        wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
    }

    var amount: Decimal? {
        inputAmount
    }

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactory
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.dataValidatingFactory = dataValidatingFactory
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

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, locale: locale)
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
}

extension StakingUnbondSetupPoolViewModelState: StakingUnbondSetupPoolStrategyOutput {
    func didReceive(error: Error) {
        stateListener?.didReceiveError(error: error)
    }

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

    func didReceive(stakeInfo: StakingPoolMember?) {
        if let bonded = stakeInfo?.points {
            self.bonded = Decimal.fromSubstrateAmount(bonded, precision: Int16(chainAsset.asset.precision))

            stateListener?.provideAssetViewModel()
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
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceive(stakingDuration: StakingDuration) {
        self.stakingDuration = stakingDuration
        stateListener?.provideBondingDuration()
    }
}
