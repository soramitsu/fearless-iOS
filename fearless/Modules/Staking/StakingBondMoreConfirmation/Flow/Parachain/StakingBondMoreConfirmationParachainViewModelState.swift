import Foundation
import BigInt

final class StakingBondMoreConfirmationParachainViewModelState: StakingBondMoreConfirmationViewModelState {
    var accountAddress: String? {
        wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
    }

    var stateListener: StakingBondMoreConfirmationModelStateListener?

    func setStateListener(_ stateListener: StakingBondMoreConfirmationModelStateListener?) {
        self.stateListener = stateListener
    }

    private let chainAsset: ChainAsset
    private var wallet: MetaAccountModel
    let amount: Decimal

    var stashAccount: ChainAccountResponse?
    var balance: Decimal?
    private var priceData: PriceData?
    var fee: Decimal?
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let candidate: AccountId

    private lazy var callFactory = SubstrateCallFactory()

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        amount: Decimal,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        candidate: AccountId
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.amount = amount
        self.dataValidatingFactory = dataValidatingFactory
        self.candidate = candidate
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
        guard let amountValue = amount.toSubstrateAmount(
            precision: Int16(chainAsset.asset.precision)
        ) else {
//            output?.didReceiveFee(result: .failure(CommonError.undefined))
            return nil
        }

        let bondExtra = callFactory.delegatorBondMore(candidate: candidate, amount: amountValue)

        return { builder in
            try builder.adding(call: bondExtra)
        }
    }

    var feeReuseIdentifier: String? {
        guard let amountValue = amount.toSubstrateAmount(
            precision: Int16(chainAsset.asset.precision)
        ) else {
            return nil
        }

        let bondExtra = callFactory.delegatorBondMore(candidate: candidate, amount: amountValue)
        return bondExtra.callName
    }
}

extension StakingBondMoreConfirmationParachainViewModelState: StakingBondMoreConfirmationParachainStrategyOutput {
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
