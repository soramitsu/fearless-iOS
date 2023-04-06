import Foundation
import BigInt

final class StakingRedeemConfirmationRelaychainViewModelState: StakingRedeemConfirmationViewModelState {
    private let callFactory: SubstrateCallFactoryProtocol
    var stateListener: StakingRedeemConfirmationModelStateListener?
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let dataValidatingFactory: StakingDataValidatingFactory
    private(set) var stakingLedger: StakingLedger?
    private(set) var activeEra: UInt32?
    private(set) var balance: Decimal?
    private(set) var minimalBalance: BigUInt?
    private(set) var fee: Decimal?
    private(set) var controller: ChainAccountResponse?
    private(set) var stashItem: StashItem?
    private(set) var numberOfSlashingSpans: Int?

    var builderClosure: ExtrinsicBuilderClosure? {
        guard let numberOfSlashingSpans = numberOfSlashingSpans else {
            return nil
        }

        let withdrawUnbonded = callFactory.withdrawUnbonded(for: UInt32(numberOfSlashingSpans))
        return { builder in
            try builder.adding(call: withdrawUnbonded)
        }
    }

    var reuseIdentifier: String? {
        (numberOfSlashingSpans ?? 0).description
    }

    var address: String? {
        stashItem?.controller
    }

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactory,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.dataValidatingFactory = dataValidatingFactory
        self.callFactory = callFactory
    }

    func setStateListener(_ stateListener: StakingRedeemConfirmationModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using locale: Locale) -> [DataValidating] {
        [
            dataValidatingFactory.hasRedeemable(
                stakingLedger: stakingLedger,
                in: activeEra,
                locale: locale
            ),

            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.stateListener?.refreshFeeIfNeeded()
            }),

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, locale: locale),

            dataValidatingFactory.has(
                controller: controller,
                for: stashItem?.controller ?? "",
                locale: locale
            )
        ]
    }
}

extension StakingRedeemConfirmationRelaychainViewModelState: StakingRedeemConfirmationRelaychainStrategyOutput {
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
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>) {
        switch result {
        case let .success(stakingLedger):
            self.stakingLedger = stakingLedger

            stateListener?.provideConfirmationViewModel()
            stateListener?.provideAssetViewModel()
            stateListener?.refreshFeeIfNeeded()
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

    func didReceiveController(result: Result<ChainAccountResponse?, Error>) {
        switch result {
        case let .success(accountItem):
            if let accountItem = accountItem {
                controller = accountItem
            }

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
}
