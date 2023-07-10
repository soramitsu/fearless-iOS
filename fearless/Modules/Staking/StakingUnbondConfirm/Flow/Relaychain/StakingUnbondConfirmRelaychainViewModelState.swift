import Foundation
import BigInt
import SSFUtils
import SSFModels

final class StakingUnbondConfirmRelaychainViewModelState: StakingUnbondConfirmViewModelState {
    var stateListener: StakingUnbondConfirmModelStateListener?
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let dataValidatingFactory: StakingDataValidatingFactory
    let inputAmount: Decimal
    private let callFactory: SubstrateCallFactoryProtocol
    private(set) var bonded: Decimal?
    private(set) var balance: Decimal?
    private(set) var minimalBalance: Decimal?
    private(set) var minNominatorBonded: Decimal?
    private(set) var nomination: Nomination?
    private(set) var fee: Decimal?
    private(set) var controller: ChainAccountResponse?
    private(set) var stashItem: StashItem?
    private(set) var payee: RewardDestinationArg?

    var builderClosure: ExtrinsicBuilderClosure? {
        { [weak self] builder in
            guard let strongSelf = self else {
                throw CommonError.undefined
            }

            return try strongSelf.setupExtrinsicBuiler(
                builder,
                amount: strongSelf.inputAmount,
                resettingRewardDestination: strongSelf.shouldResetRewardDestination,
                chilling: strongSelf.shouldChill
            )
        }
    }

    var builderClosureOld: ExtrinsicBuilderClosure? {
        nil
    }

    var reuseIdentifier: String? {
        inputAmount.description + shouldResetRewardDestination.description
    }

    var accountAddress: AccountAddress? {
        stashItem?.controller
    }

    var shouldResetRewardDestination: Bool {
        switch payee {
        case .staked:
            if let bonded = bonded, let minimalBalance = minimalBalance {
                return bonded - inputAmount < minimalBalance || bonded == inputAmount
            } else {
                return false
            }
        default:
            return false
        }
    }

    private var shouldChill: Bool {
        if let bonded = bonded, let minNominatorBonded = minNominatorBonded, nomination != nil {
            return bonded - inputAmount < minNominatorBonded || bonded == inputAmount
        } else {
            return false
        }
    }

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactory,
        inputAmount: Decimal,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.dataValidatingFactory = dataValidatingFactory
        self.inputAmount = inputAmount
        self.callFactory = callFactory
    }

    func setStateListener(_ stateListener: StakingUnbondConfirmModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using locale: Locale) -> [DataValidating] {
        [
            dataValidatingFactory.canUnbond(amount: inputAmount, bonded: bonded, locale: locale),

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
}

extension StakingUnbondConfirmRelaychainViewModelState: StakingUnbondConfirmRelaychainStrategyOutput {
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
            self.minimalBalance = Decimal.fromSubstrateAmount(
                minimalBalance,
                precision: Int16(chainAsset.asset.precision)
            )

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

    func didReceivePayee(result: Result<RewardDestinationArg?, Error>) {
        switch result {
        case let .success(payee):
            self.payee = payee

            stateListener?.refreshFeeIfNeeded()

            stateListener?.provideConfirmationViewModel()
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

            stateListener?.refreshFeeIfNeeded()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didReceiveNomination(result: Result<Nomination?, Error>) {
        switch result {
        case let .success(nomination):
            self.nomination = nomination
            stateListener?.refreshFeeIfNeeded()
        case let .failure(error):
            stateListener?.didReceiveError(error: error)
        }
    }

    func didSubmitUnbonding(result: Result<String, Error>) {
        stateListener?.didSubmitUnbonding(result: result)
    }
}
