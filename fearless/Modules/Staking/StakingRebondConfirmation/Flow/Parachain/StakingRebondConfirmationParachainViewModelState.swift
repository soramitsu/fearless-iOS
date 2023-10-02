import Foundation
import BigInt
import SSFModels

final class StakingRebondConfirmationParachainViewModelState: StakingRebondConfirmationViewModelState {
    var stateListener: StakingRebondConfirmationModelStateListener?
    let delegation: ParachainStakingDelegationInfo
    let request: ParachainStakingScheduledRequest
    let wallet: MetaAccountModel
    let chainAsset: ChainAsset
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    private let callFactory: SubstrateCallFactoryProtocol
    let logger: LoggerProtocol?

    private(set) var balance: Decimal?
    private(set) var fee: Decimal?

    var inputAmount: Decimal {
        var amount: Decimal = 0
        switch request.action {
        case let .revoke(revokeAmount):
            amount = Decimal.fromSubstrateAmount(revokeAmount, precision: Int16(chainAsset.asset.precision)) ?? 0
        case let .decrease(decreaseAmount):
            amount = Decimal.fromSubstrateAmount(decreaseAmount, precision: Int16(chainAsset.asset.precision)) ?? 0
        }
        return amount
    }

    var builderClosure: ExtrinsicBuilderClosure? {
        let closure: ExtrinsicBuilderClosure = { [weak self] builder in
            guard let strongSelf = self else {
                return builder
            }
            var newBuilder = builder

            if strongSelf.isCollator {
                let call = strongSelf.callFactory.cancelCandidateBondLess()
                newBuilder = try newBuilder.adding(call: call)
            } else {
                let call = strongSelf.callFactory.cancelDelegationRequest(candidate: strongSelf.delegation.collator.owner)
                newBuilder = try newBuilder.adding(call: call)
            }

            return newBuilder
        }

        return closure
    }

    var reuseIdentifier: String? {
        var identifier: String?

        if isCollator {
            let call = callFactory.cancelCandidateBondLess()
            identifier = call.callName
        } else {
            let call = callFactory.cancelDelegationRequest(candidate: delegation.collator.owner)
            identifier = call.callName
        }

        return identifier
    }

    var selectableAccountAddress: String? {
        wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
    }

    private var isRevoke: Bool {
        switch request.action {
        case .revoke:
            return true
        default:
            return false
        }
    }

    private var isCollator: Bool {
        delegation.collator.owner == wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId
    }

    init(
        delegation: ParachainStakingDelegationInfo,
        request: ParachainStakingScheduledRequest,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        logger: LoggerProtocol?,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.delegation = delegation
        self.request = request
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        self.callFactory = callFactory
    }

    func setStateListener(_ stateListener: StakingRebondConfirmationModelStateListener?) {
        self.stateListener = stateListener
    }

    func dataValidators(locale _: Locale) -> [DataValidating] {
        []
    }
}

extension StakingRebondConfirmationParachainViewModelState: StakingRebondConfirmationParachainStrategyOutput {
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
            logger?.error("Account Info subscription error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let fee = BigUInt(string: dispatchInfo.fee) {
                self.fee = Decimal.fromSubstrateAmount(fee, precision: Int16(chainAsset.asset.precision))
            } else {
                fee = nil
            }

            stateListener?.provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didSubmitRebonding(result: Result<String, Error>) {
        stateListener?.didSubmitRebonding(result: result)
    }
}
