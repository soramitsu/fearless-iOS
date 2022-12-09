import Foundation
import BigInt

final class StakingUnbondSetupRelaychainViewModelState: StakingUnbondSetupViewModelState {
    var stateListener: StakingUnbondSetupModelStateListener?
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    private(set) var bonded: Decimal?
    private(set) var balance: Decimal?
    private(set) var inputAmount: Decimal?
    private(set) var bondingDuration: UInt32?
    private(set) var minimalBalance: Decimal?
    private(set) var fee: Decimal?
    private(set) var controller: ChainAccountResponse?
    private(set) var stashItem: StashItem?
    private let dataValidatingFactory: StakingDataValidatingFactory
    private let callFactory: SubstrateCallFactoryProtocol = SubstrateCallFactory()

    var builderClosure: ExtrinsicBuilderClosure? {
        guard
            let amount = StakingConstants.maxAmount.toSubstrateAmount(
                precision: Int16(chainAsset.asset.precision)
            ) else {
            return nil
        }

        let unbondCall = callFactory.unbond(amount: amount)
        let setPayeeCall = callFactory.setPayee(for: .stash)
        let chillCall = callFactory.chill()

        return { builder in
            try builder.adding(call: chillCall).adding(call: unbondCall).adding(call: setPayeeCall)
        }
    }

    var confirmationFlow: StakingUnbondConfirmFlow? {
        guard let inputAmount = inputAmount else {
            return nil
        }

        return .relaychain(amount: inputAmount)
    }

    var amount: Decimal? {
        inputAmount
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

    func setStateListener(_ stateListener: StakingUnbondSetupModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using locale: Locale) -> [DataValidating] {
        [
            dataValidatingFactory.canUnbond(amount: inputAmount, bonded: bonded, locale: locale),

            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.stateListener?.updateFeeIfNeeded()
            }),

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, locale: locale),

            dataValidatingFactory.has(
                controller: controller,
                for: stashItem?.controller ?? "",
                locale: locale
            ),

            dataValidatingFactory.stashIsNotKilledAfterUnbonding(
                amount: inputAmount,
                bonded: bonded,
                minimumAmount: minimalBalance,
                locale: locale
            )
        ]
    }

    func selectAmountPercentage(_ percentage: Float) {
        if let bonded = bonded {
            inputAmount = bonded * Decimal(Double(percentage))
            stateListener?.provideInputViewModel()
            stateListener?.provideAssetViewModel()
        }
    }

    func updateAmount(_ amount: Decimal) {
        inputAmount = amount
        stateListener?.provideAssetViewModel()

        if fee == nil {
            stateListener?.updateFeeIfNeeded()
        }
    }
}

extension StakingUnbondSetupRelaychainViewModelState: StakingUnbondSetupRelaychainStrategyOutput {
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
            if let stakingLedger = stakingLedger {
                bonded = Decimal.fromSubstrateAmount(
                    stakingLedger.active,
                    precision: Int16(chainAsset.asset.precision)
                )
            } else {
                bonded = nil
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

    func didReceiveBondingDuration(result: Result<UInt32, Error>) {
        switch result {
        case let .success(bondingDuration):
            self.bondingDuration = bondingDuration
            stateListener?.provideBondingDuration()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimalBalance):
            self.minimalBalance = Decimal.fromSubstrateAmount(
                minimalBalance,
                precision: Int16(chainAsset.asset.precision)
            )
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
}
