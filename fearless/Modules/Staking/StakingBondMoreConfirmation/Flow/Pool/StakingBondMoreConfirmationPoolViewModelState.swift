import Foundation
import BigInt

final class StakingBondMoreConfirmationPoolViewModelState: StakingBondMoreConfirmationViewModelState {
    var stateListener: StakingBondMoreConfirmationModelStateListener?
    var balance: Decimal?
    var fee: Decimal?
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let amount: Decimal
    private var priceData: PriceData?
    private let chainAsset: ChainAsset
    private var wallet: MetaAccountModel
    private lazy var callFactory = SubstrateCallFactory()

    var accountAddress: String? {
        wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
    }

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        amount: Decimal,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.amount = amount
        self.dataValidatingFactory = dataValidatingFactory
    }

    func validators(using locale: Locale) -> [DataValidating] {
        [
            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.stateListener?.refreshFeeIfNeeded()
            }),

            dataValidatingFactory.canPayFeeAndAmount(
                balance: balance,
                fee: fee,
                spendingAmount: amount,
                locale: locale
            )
        ]
    }

    var builderClosure: ExtrinsicBuilderClosure? {
        guard let amount = amount.toSubstrateAmount(precision: Int16(chainAsset.asset.precision)) else {
            return nil
        }

        return { [weak self] builder in
            guard let strongSelf = self else {
                return builder
            }

            let call = strongSelf.callFactory.poolBondMore(
                amount: amount
            )

            return try builder.adding(call: call)
        }
    }

    var feeReuseIdentifier: String? {
        guard let amount = amount.toSubstrateAmount(
            precision: Int16(chainAsset.asset.precision)
        ) else {
            return nil
        }

        let call = callFactory.poolBondMore(
            amount: amount
        )

        return call.callName
    }

    func setStateListener(_ stateListener: StakingBondMoreConfirmationModelStateListener?) {
        self.stateListener = stateListener
    }
}

extension StakingBondMoreConfirmationPoolViewModelState: StakingBondMoreConfirmationPoolStrategyOutput {
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

            stateListener?.provideAssetViewModel()
            stateListener?.provideConfirmationViewModel()
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

            stateListener?.provideFeeViewModel()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didSubmitBonding(result: Result<String, Error>) {
        stateListener?.didSubmitBonding(result: result)
    }
}
