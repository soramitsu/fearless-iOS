import Foundation
import BigInt

final class StakingRedeemPoolViewModelState: StakingRedeemViewModelState {
    var stateListener: StakingRedeemModelStateListener?
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let dataValidatingFactory: StakingDataValidatingFactory

    private(set) var activeEra: UInt32?
    private(set) var balance: Decimal?
    private(set) var minimalBalance: BigUInt?
    private(set) var fee: Decimal?
    private(set) var numberOfSlashingSpans: Int?
    private(set) var stakeInfo: StakingPoolMember?

    private lazy var callFactory = SubstrateCallFactory()

    var builderClosure: ExtrinsicBuilderClosure? {
        guard let numberOfSlashingSpans = numberOfSlashingSpans,
              let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return nil
        }

        let withdrawUnbonded = callFactory.poolWithdrawUnbonded(
            accountId: accountId,
            numSlashingSpans: UInt32(numberOfSlashingSpans)
        )

        return { builder in
            try builder.adding(call: withdrawUnbonded)
        }
    }

    var reuseIdentifier: String? {
        (numberOfSlashingSpans ?? 0).description
    }

    var address: String? {
        wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
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

    func setStateListener(_ stateListener: StakingRedeemModelStateListener?) {
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

extension StakingRedeemPoolViewModelState: StakingRedeemPoolStrategyOutput {
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

    func didReceiveSlashingSpans(result: Result<SlashingSpans?, Error>) {
        switch result {
        case let .success(slashingSpans):
            numberOfSlashingSpans = (slashingSpans?.prior.count ?? 0) + 1

            stateListener?.refreshFeeIfNeeded()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveStakeInfo(result: Result<StakingPoolMember?, Error>) {
        switch result {
        case let .success(stakeInfo):
            self.stakeInfo = stakeInfo

            stateListener?.provideAssetViewModel()
            stateListener?.provideConfirmationViewModel()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveActiveEra(result: Result<ActiveEraInfo?, Error>) {
        switch result {
        case let .success(eraInfo):
            activeEra = eraInfo?.index

            stateListener?.provideAssetViewModel()
            stateListener?.provideConfirmationViewModel()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }
}
