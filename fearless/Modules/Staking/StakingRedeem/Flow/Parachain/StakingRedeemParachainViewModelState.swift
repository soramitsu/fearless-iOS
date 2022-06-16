import Foundation
import BigInt

final class StakingRedeemParachainViewModelState: StakingRedeemViewModelState {
    private lazy var callFactory = SubstrateCallFactory()

    func validators(using locale: Locale) -> [DataValidating] {
        [
            // TODO: Has redeemable check
//            dataValidatingFactory.hasRedeemable(
//                stakingLedger: stakingLedger,
//                in: activeEra,
//                locale: locale
//            ),

            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.stateListener?.refreshFeeIfNeeded()
            }),

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, locale: locale)
        ]
    }

    var builderClosure: ExtrinsicBuilderClosure? {
        let call = callFactory.scheduleRevokeDelegation(candidate: collator.owner)

        return { builder in
            try builder.adding(call: call)
        }
    }

    var reuseIdentifier: String? {
        let call = callFactory.scheduleRevokeDelegation(candidate: collator.owner)

        return call.callName
    }

    var address: String? {
        wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
    }

    var stateListener: StakingRedeemModelStateListener?

    func setStateListener(_ stateListener: StakingRedeemModelStateListener?) {
        self.stateListener = stateListener
    }

    let readyForRevoke: BigUInt
    let delegation: ParachainStakingDelegation
    let collator: ParachainStakingCandidateInfo
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let dataValidatingFactory: StakingDataValidatingFactory

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

    private(set) var activeEra: UInt32?
    private(set) var balance: Decimal?
    private(set) var minimalBalance: BigUInt?
    private(set) var fee: Decimal?
}

extension StakingRedeemParachainViewModelState: StakingRedeemParachainStrategyOutput {
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
