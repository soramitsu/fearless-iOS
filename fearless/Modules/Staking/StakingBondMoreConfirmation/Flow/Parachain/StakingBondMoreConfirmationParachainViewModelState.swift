import Foundation
import BigInt
import SSFModels

final class StakingBondMoreConfirmationParachainViewModelState: StakingBondMoreConfirmationViewModelState {
    var stateListener: StakingBondMoreConfirmationModelStateListener?
    var stashAccount: ChainAccountResponse?
    var balance: Decimal?
    var fee: Decimal?
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let amount: Decimal
    private var priceData: PriceData?
    private let chainAsset: ChainAsset
    private var wallet: MetaAccountModel
    private let callFactory: SubstrateCallFactoryProtocol

    var accountAddress: String? {
        wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
    }

    let candidate: ParachainStakingCandidateInfo

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        amount: Decimal,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        candidate: ParachainStakingCandidateInfo,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.amount = amount
        self.dataValidatingFactory = dataValidatingFactory
        self.candidate = candidate
        self.callFactory = callFactory
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

    private var isCollator: Bool {
        candidate.owner == wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId
    }

    var builderClosure: ExtrinsicBuilderClosure? {
        guard let amount = amount.toSubstrateAmount(precision: Int16(chainAsset.asset.precision)) else {
            return nil
        }

        return { [weak self] builder in
            guard let strongSelf = self else {
                return builder
            }

            var newBuilder = builder

            if strongSelf.isCollator {
                let call = strongSelf.callFactory.candidateBondMore(amount: amount)
                newBuilder = try newBuilder.adding(call: call)
            } else {
                let call = strongSelf.callFactory.delegatorBondMore(
                    candidate: strongSelf.candidate.owner,
                    amount: amount
                )
                newBuilder = try newBuilder.adding(call: call)
            }

            return newBuilder
        }
    }

    var feeReuseIdentifier: String? {
        guard let amount = amount.toSubstrateAmount(
            precision: Int16(chainAsset.asset.precision)
        ) else {
            return nil
        }
        var identifier = ""
        if isCollator {
            let call = callFactory.candidateBondMore(amount: amount)
            identifier = call.callName
        } else {
            let call = callFactory.delegatorBondMore(candidate: candidate.owner, amount: amount)
            identifier = call.callName
        }

        return identifier
    }

    func setStateListener(_ stateListener: StakingBondMoreConfirmationModelStateListener?) {
        self.stateListener = stateListener
    }
}

extension StakingBondMoreConfirmationParachainViewModelState: StakingBondMoreConfirmationParachainStrategyOutput {
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
