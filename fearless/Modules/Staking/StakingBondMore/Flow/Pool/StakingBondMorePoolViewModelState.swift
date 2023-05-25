import Foundation
import BigInt

final class StakingBondMorePoolViewModelState {
    var stateListener: StakingBondMoreModelStateListener?
    private let callFactory: SubstrateCallFactoryProtocol
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    var amount: Decimal = 0
    var fee: Decimal?
    var balance: Decimal?
    private var minimalBalance: Decimal?

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.dataValidatingFactory = dataValidatingFactory
        self.callFactory = callFactory
    }

    var accountAddress: AccountAddress? {
        wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
    }
}

extension StakingBondMorePoolViewModelState: StakingBondMoreViewModelState {
    func validators(using locale: Locale) -> [DataValidating] {
        let amountSubstrate = amount.toSubstrateAmount(precision: Int16(chainAsset.asset.precision))
        let balanceSubstrate = balance?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision))
        let edSubstrate = minimalBalance?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision))

        return [
            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [unowned self] in
                self.stateListener?.feeParametersDidChanged(viewModelState: self)
            }),
            dataValidatingFactory.canPayFeeAndAmount(
                balance: balance,
                fee: fee,
                spendingAmount: amount,
                locale: locale
            ),
            dataValidatingFactory.exsitentialDepositIsNotViolated(
                spendingAmount: amountSubstrate,
                totalAmount: balanceSubstrate,
                minimumBalance: edSubstrate,
                locale: locale,
                chainAsset: chainAsset,
                canProceedIfViolated: false
            )
        ]
    }

    func updateAmount(_ newValue: Decimal) {
        amount = newValue

        stateListener?.provideAsset()
        stateListener?.feeParametersDidChanged(viewModelState: self)
    }

    func selectAmountPercentage(_ percentage: Float) {
        if let balance = balance, let fee = fee, let minimalBalance = minimalBalance {
            let newAmount = max(balance - fee - minimalBalance, 0.0) * Decimal(Double(percentage))

            if newAmount > 0 {
                amount = newAmount

                stateListener?.provideAmountInputViewModel()
                stateListener?.provideAsset()
            } else {
                stateListener?.didReceiveInsufficientlyFundsError()
            }
        }
    }

    var feeReuseIdentifier: String? {
        guard let amount = StakingConstants.maxAmount.toSubstrateAmount(
            precision: Int16(chainAsset.asset.precision)
        ) else {
            return nil
        }

        let call = callFactory.poolBondMore(amount: amount)

        return call.callName
    }

    func setStateListener(_ stateListener: StakingBondMoreModelStateListener?) {
        self.stateListener = stateListener
    }

    var builderClosure: ExtrinsicBuilderClosure? {
        guard let amount = StakingConstants.maxAmount.toSubstrateAmount(
            precision: Int16(chainAsset.asset.precision)
        ) else {
            return nil
        }

        return { [weak self] builder in
            guard let strongSelf = self else {
                return builder
            }

            let call = strongSelf.callFactory.poolBondMore(amount: amount)

            return try builder.adding(call: call)
        }
    }

    var bondMoreConfirmationFlow: StakingBondMoreConfirmationFlow? {
        .pool(amount: amount)
    }
}

extension StakingBondMorePoolViewModelState: StakingBondMorePoolStrategyOutput {
    func didSetup() {
        stateListener?.provideAccountViewModel()
        stateListener?.provideCollatorViewModel()
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

            stateListener?.provideAsset()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let feeValue = BigUInt(dispatchInfo.fee) {
                fee = Decimal.fromSubstrateAmount(feeValue, precision: Int16(chainAsset.asset.precision))
            } else {
                fee = nil
            }

            stateListener?.provideFee()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(existentialDeposit):
            let amount = Decimal.fromSubstrateAmount(existentialDeposit, precision: Int16(chainAsset.asset.precision))
            minimalBalance = amount
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func extrinsicServiceUpdated() {
        stateListener?.feeParametersDidChanged(viewModelState: self)
    }
}
