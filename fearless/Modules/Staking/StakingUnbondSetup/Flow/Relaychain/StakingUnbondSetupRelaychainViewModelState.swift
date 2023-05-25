import Foundation
import BigInt
import FearlessUtils

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
    private(set) var payee: RewardDestinationArg?
    private(set) var minNominatorBonded: Decimal?
    private(set) var nomination: Nomination?
    private let dataValidatingFactory: StakingDataValidatingFactory
    private let callFactory: SubstrateCallFactoryProtocol

    var confirmationFlow: StakingUnbondConfirmFlow? {
        guard let inputAmount = inputAmount else {
            return nil
        }

        return .relaychain(amount: inputAmount)
    }

    var amount: Decimal? {
        inputAmount
    }

    var reuseIdentifier: String {
        var identifier = ""
        let amountValue = inputAmount?.toSubstrateAmount(precision: Int16(chainAsset.asset.precision)) ?? BigUInt.zero
        identifier.append("\(amountValue)")

        if shouldChill {
            let chillName = callFactory.chill().callName
            identifier.append(chillName)
        }

        let unbondName = callFactory.unbond(amount: amountValue).callName
        identifier.append(unbondName)

        if shouldResetRewardDestination {
            let resetName = callFactory.setPayee(for: .stash).callName
            identifier.append(resetName)
        }

        return identifier
    }

    var builderClosure: ExtrinsicBuilderClosure? {
        { [weak self] builder in
            guard let strongSelf = self else {
                throw CommonError.undefined
            }

            let amount = strongSelf.inputAmount ?? Decimal.zero

            return try strongSelf.setupExtrinsicBuiler(
                builder,
                amount: amount,
                resettingRewardDestination: strongSelf.shouldResetRewardDestination,
                chilling: strongSelf.shouldChill
            )
        }
    }

    private var shouldChill: Bool {
        let amount = inputAmount ?? Decimal.zero
        if
            let bonded = bonded,
            let minNominatorBonded = minNominatorBonded,
            nomination != nil {
            return bonded - amount < minNominatorBonded || amount == bonded
        } else {
            return false
        }
    }

    private var shouldResetRewardDestination: Bool {
        let amount = inputAmount ?? Decimal.zero
        switch payee {
        case .staked:
            if let bonded = bonded, let minimalBalance = minimalBalance {
                return bonded - amount < minimalBalance || amount == bonded
            } else {
                return false
            }
        default:
            return false
        }
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

    private func setupExtrinsicBuiler(
        _ builder: ExtrinsicBuilderProtocol,
        amount: Decimal,
        resettingRewardDestination: Bool,
        chilling: Bool
    ) throws -> ExtrinsicBuilderProtocol {
        guard let amountValue = amount.toSubstrateAmount(precision: Int16(chainAsset.asset.precision)) else {
            throw CommonError.undefined
        }

        var resultBuilder = builder

        if chilling {
            resultBuilder = try builder.adding(call: callFactory.chill())
        }

        resultBuilder = try resultBuilder.adding(call: callFactory.unbond(amount: amountValue))

        if resettingRewardDestination {
            resultBuilder = try resultBuilder.adding(call: callFactory.setPayee(for: .stash))
        }

        return resultBuilder
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
            stateListener?.updateFeeIfNeeded()
        }
    }

    func updateAmount(_ amount: Decimal) {
        inputAmount = amount
        stateListener?.provideAssetViewModel()
        stateListener?.updateFeeIfNeeded()
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

    func didReceivePayee(result: Result<RewardDestinationArg?, Error>) {
        switch result {
        case let .success(payee):
            self.payee = payee

            stateListener?.updateFeeIfNeeded()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveMinBonded(result: Result<BigUInt?, Error>) {
        switch result {
        case let .success(minNominatorBonded):
            if let minNominatorBonded = minNominatorBonded {
                self.minNominatorBonded = Decimal.fromSubstrateAmount(
                    minNominatorBonded,
                    precision: Int16(chainAsset.asset.precision)
                )
            } else {
                self.minNominatorBonded = Decimal.zero
            }

            stateListener?.updateFeeIfNeeded()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveNomination(result: Result<Nomination?, Error>) {
        switch result {
        case let .success(nomination):
            self.nomination = nomination

            stateListener?.updateFeeIfNeeded()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveNewExtrinsicService() {
        stateListener?.updateFeeIfNeeded()
    }
}
