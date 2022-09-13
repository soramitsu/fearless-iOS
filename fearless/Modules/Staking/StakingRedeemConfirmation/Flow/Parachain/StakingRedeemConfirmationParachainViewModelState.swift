import Foundation
import BigInt

final class StakingRedeemConfirmationParachainViewModelState: StakingRedeemConfirmationViewModelState {
    var stateListener: StakingRedeemConfirmationModelStateListener?
    let readyForRevoke: BigUInt
    let delegation: ParachainStakingDelegation
    let collator: ParachainStakingCandidateInfo
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let dataValidatingFactory: StakingDataValidatingFactory

    private(set) var activeEra: UInt32?
    private(set) var balance: Decimal?
    private(set) var minimalBalance: BigUInt?
    private(set) var fee: Decimal?

    private lazy var callFactory = SubstrateCallFactory()

    var builderClosure: ExtrinsicBuilderClosure? {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return nil
        }
        let call = callFactory.executeDelegationRequest(delegator: accountId, collator: collator.owner)

        return { builder in
            try builder.adding(call: call)
        }
    }

    var reuseIdentifier: String? {
        let call = callFactory.executeDelegationRequest(delegator: delegation.owner, collator: collator.owner)

        return call.callName
    }

    var address: String? {
        wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
    }

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactory,
        delegation: ParachainStakingDelegation,
        collator: ParachainStakingCandidateInfo,
        readyForRevoke: BigUInt
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.dataValidatingFactory = dataValidatingFactory
        self.delegation = delegation
        self.collator = collator
        self.readyForRevoke = readyForRevoke
    }

    func setStateListener(_ stateListener: StakingRedeemConfirmationModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using locale: Locale) -> [DataValidating] {
        [
            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.stateListener?.refreshFeeIfNeeded()
            }),

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, locale: locale)
        ]
    }
}

extension StakingRedeemConfirmationParachainViewModelState: StakingRedeemConfirmationParachainStrategyOutput {
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
            self.minimalBalance = minimalBalance

            stateListener?.provideAssetViewModel()
            stateListener?.refreshFeeIfNeeded()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didSubmitRedeeming(result: Result<String, Error>) {
        stateListener?.didSubmitRedeeming(result: result)
    }
}
