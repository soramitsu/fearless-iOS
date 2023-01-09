import Foundation
import BigInt

final class StakingRebondConfirmationRelaychainViewModelState: StakingRebondConfirmationViewModelState {
    let callFactory = SubstrateCallFactory()
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let logger: LoggerProtocol?
    let variant: SelectedRebondVariant
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol

    private(set) var stakingLedger: StakingLedger?
    private(set) var activeEra: UInt32?
    private(set) var balance: Decimal?
    private(set) var fee: Decimal?
    private(set) var controller: ChainAccountResponse?
    private(set) var stashItem: StashItem?

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        logger: LoggerProtocol?,
        variant: SelectedRebondVariant,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.logger = logger
        self.variant = variant
        self.dataValidatingFactory = dataValidatingFactory
    }

    var inputAmount: Decimal? {
        switch variant {
        case .all:
            if
                let ledger = stakingLedger,
                let era = activeEra {
                let value = ledger.unbonding(inEra: era)
                return Decimal.fromSubstrateAmount(value, precision: Int16(chainAsset.asset.precision))
            } else {
                return nil
            }
        case .last:
            if
                let ledger = stakingLedger,
                let era = activeEra,
                let chunk = ledger.unbondings(inEra: era).last {
                return Decimal.fromSubstrateAmount(chunk.value, precision: Int16(chainAsset.asset.precision))
            } else {
                return nil
            }
        case let .custom(amount):
            return amount
        }
    }

    var unbonding: Decimal? {
        if let activeEra = activeEra, let value = stakingLedger?.unbonding(inEra: activeEra) {
            return Decimal.fromSubstrateAmount(value, precision: Int16(chainAsset.asset.precision))
        } else {
            return nil
        }
    }

    var selectableAccountAddress: String? {
        stashItem?.controller
    }

    var stateListener: StakingRebondConfirmationModelStateListener?

    func setStateListener(_ stateListener: StakingRebondConfirmationModelStateListener?) {
        self.stateListener = stateListener
    }

    var builderClosure: ExtrinsicBuilderClosure? {
        guard let amountValue = inputAmount?.toSubstrateAmount(
            precision: Int16(chainAsset.asset.precision)
        ) else {
            return nil
        }

        let rebondCall = callFactory.rebond(amount: amountValue)

        return { builder in
            try builder.adding(call: rebondCall)
        }
    }

    var reuseIdentifier: String? {
        guard let amountValue = inputAmount?.toSubstrateAmount(
            precision: Int16(chainAsset.asset.precision)
        ) else {
            return nil
        }

        let rebondCall = callFactory.rebond(amount: amountValue)

        return rebondCall.callName
    }

    func dataValidators(locale: Locale) -> [DataValidating] {
        [
            dataValidatingFactory.canRebond(amount: inputAmount, unbonding: unbonding, locale: locale),

            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.stateListener?.feeParametersDidChanged()
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

extension StakingRebondConfirmationRelaychainViewModelState: StakingRebondConfirmationRelaychainStrategyOutput {
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

    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>) {
        switch result {
        case let .success(stakingLedger):
            self.stakingLedger = stakingLedger

            stateListener?.provideConfirmationViewModel()
            stateListener?.provideAssetViewModel()
            stateListener?.feeParametersDidChanged()
        case let .failure(error):
            logger?.error("Staking ledger subscription error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let fee = BigUInt(dispatchInfo.fee) {
                self.fee = Decimal.fromSubstrateAmount(fee, precision: Int16(chainAsset.asset.precision))
            } else {
                fee = nil
            }

            stateListener?.provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveController(result: Result<ChainAccountResponse?, Error>) {
        switch result {
        case let .success(accountItem):
            controller = accountItem

            stateListener?.provideConfirmationViewModel()
            stateListener?.feeParametersDidChanged()
        case let .failure(error):
            logger?.error("Did receive controller account error: \(error)")
        }
    }

    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            self.stashItem = stashItem
        case let .failure(error):
            logger?.error("Did receive stash item error: \(error)")
        }
    }

    func didReceiveActiveEra(result: Result<ActiveEraInfo?, Error>) {
        switch result {
        case let .success(eraInfo):
            activeEra = eraInfo?.index

            stateListener?.provideAssetViewModel()
            stateListener?.provideConfirmationViewModel()
        case let .failure(error):
            logger?.error("Did receive active era error: \(error)")
        }
    }

    func didSubmitRebonding(result: Result<String, Error>) {
        stateListener?.didSubmitRebonding(result: result)
    }
}
