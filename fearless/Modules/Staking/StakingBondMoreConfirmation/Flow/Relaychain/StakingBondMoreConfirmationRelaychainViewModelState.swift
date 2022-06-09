import Foundation
import BigInt

final class StakingBondMoreConfirmationRelaychainViewModelState: StakingBondMoreConfirmationViewModelState {
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
    private var stashItem: StashItem?
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol

    private lazy var callFactory = SubstrateCallFactory()

    var accountAddress: String? {
        stashItem?.controller
    }

    init(chainAsset: ChainAsset, wallet: MetaAccountModel, amount: Decimal, dataValidatingFactory: StakingDataValidatingFactoryProtocol) {
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
            ),
            dataValidatingFactory.has(
                stash: stashAccount,
                for: stashItem?.stash ?? "",
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

        let bondExtra = callFactory.bondExtra(amount: amountValue)

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

        let bondExtra = callFactory.bondExtra(amount: amountValue)
        return bondExtra.callName
    }
}

extension StakingBondMoreConfirmationRelaychainViewModelState: StakingBondMoreConfirmationRelaychainStrategyOutput {
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

    func didReceiveStash(result: Result<ChainAccountResponse?, Error>) {
        switch result {
        case let .success(stashAccount):
            self.stashAccount = stashAccount

            stateListener?.provideConfirmationViewModel()

            stateListener?.refreshFeeIfNeeded()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            self.stashItem = stashItem
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didSubmitBonding(result: Result<String, Error>) {
        stateListener?.didSubmitBonding(result: result)
    }
}
