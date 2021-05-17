import Foundation
import CommonWallet
import SoraFoundation
import BigInt
import IrohaCrypto

protocol StakingStateViewModelFactoryProtocol {
    func createViewModel(from state: StakingStateProtocol) -> StakingViewState
}

final class StakingStateViewModelFactory {
    let primitiveFactory: WalletPrimitiveFactoryProtocol
    let logger: LoggerProtocol?

    private var lastViewModel: StakingViewState = .undefined

    private var balanceViewModelFactory: BalanceViewModelFactoryProtocol?
    private var rewardViewModelFactory: RewardViewModelFactoryProtocol?
    private var cachedChain: Chain?

    private lazy var addressFactory = SS58AddressFactory()

    init(primitiveFactory: WalletPrimitiveFactoryProtocol, logger: LoggerProtocol? = nil) {
        self.primitiveFactory = primitiveFactory
        self.logger = logger
    }

    private func updateCacheForChain(_ newChain: Chain) {
        if newChain != cachedChain {
            balanceViewModelFactory = nil
            rewardViewModelFactory = nil
            cachedChain = newChain
        }
    }

    private func convertAmount(
        _ amount: BigUInt?,
        for chain: Chain,
        defaultValue: Decimal
    ) -> Decimal {
        if let amount = amount {
            return Decimal.fromSubstrateAmount(
                amount,
                precision: chain.addressType.precision
            ) ?? defaultValue
        } else {
            return defaultValue
        }
    }

    private func getBalanceViewModelFactory(for chain: Chain) -> BalanceViewModelFactoryProtocol {
        if let factory = balanceViewModelFactory {
            return factory
        }

        let factory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        balanceViewModelFactory = factory

        return factory
    }

    private func getRewardViewModelFactory(for chain: Chain) -> RewardViewModelFactoryProtocol {
        if let factory = rewardViewModelFactory {
            return factory
        }

        let factory = RewardViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType
        )

        rewardViewModelFactory = factory

        return factory
    }

    private func createNominationViewModel(
        for chain: Chain,
        commonData: StakingStateCommonData,
        state: NominatorState,
        viewStatus: NominationViewStatus
    ) -> LocalizableResource<NominationViewModelProtocol> {
        let balanceViewModelFactory = getBalanceViewModelFactory(for: chain)

        let stakedAmount = convertAmount(state.ledgerInfo.active, for: chain, defaultValue: 0.0)
        let staked = balanceViewModelFactory.balanceFromPrice(
            stakedAmount,
            priceData: commonData.price
        )

        let reward: LocalizableResource<BalanceViewModelProtocol>?
        if let totalReward = state.totalReward {
            reward = balanceViewModelFactory.balanceFromPrice(
                totalReward.amount.decimalValue,
                priceData: commonData.price
            )
        } else {
            reward = nil
        }

        return LocalizableResource { locale in
            let stakedViewModel = staked.value(for: locale)
            let rewardViewModel = reward?.value(for: locale)

            return NominationViewModel(
                totalStakedAmount: stakedViewModel.amount,
                totalStakedPrice: stakedViewModel.price ?? "",
                totalRewardAmount: rewardViewModel?.amount ?? "",
                totalRewardPrice: rewardViewModel?.price ?? "",
                status: viewStatus
            )
        }
    }

    private func createValidationViewModel(
        for chain: Chain,
        commonData: StakingStateCommonData,
        state: ValidatorState,
        viewStatus: ValidationViewStatus
    ) -> LocalizableResource<ValidationViewModelProtocol> {
        let balanceViewModelFactory = getBalanceViewModelFactory(for: chain)

        let stakedAmount = convertAmount(state.ledgerInfo.active, for: chain, defaultValue: 0.0)
        let staked = balanceViewModelFactory.balanceFromPrice(
            stakedAmount,
            priceData: commonData.price
        )

        let reward: LocalizableResource<BalanceViewModelProtocol>?
        if let totalReward = state.totalReward {
            reward = balanceViewModelFactory.balanceFromPrice(
                totalReward.amount.decimalValue,
                priceData: commonData.price
            )
        } else {
            reward = nil
        }

        return LocalizableResource { locale in
            let stakedViewModel = staked.value(for: locale)
            let rewardViewModel = reward?.value(for: locale)

            return ValidationViewModel(
                totalStakedAmount: stakedViewModel.amount,
                totalStakedPrice: stakedViewModel.price ?? "",
                totalRewardAmount: rewardViewModel?.amount ?? "",
                totalRewardPrice: rewardViewModel?.price ?? "",
                status: viewStatus
            )
        }
    }

    private func createPeriodReward(
        for chain: Chain,
        commonData: StakingStateCommonData,
        amount: Decimal?
    ) throws -> LocalizableResource<PeriodRewardViewModel>? {
        guard let calculator = commonData.calculatorEngine else {
            return nil
        }

        let rewardViewModelFactory = getRewardViewModelFactory(for: chain)

        let monthlyReturn = calculator.calculateMaxReturn(isCompound: true, period: .month)

        let yearlyReturn = calculator.calculateMaxReturn(isCompound: true, period: .year)

        let monthlyViewModel = rewardViewModelFactory.createRewardViewModel(
            reward: (amount ?? 0.0) * monthlyReturn,
            targetReturn: monthlyReturn,
            priceData: commonData.price
        )

        let yearlyViewModel = rewardViewModelFactory.createRewardViewModel(
            reward: (amount ?? 0.0) * yearlyReturn,
            targetReturn: yearlyReturn,
            priceData: commonData.price
        )

        return LocalizableResource { locale in
            PeriodRewardViewModel(
                monthlyReward: monthlyViewModel.value(for: locale),
                yearlyReward: yearlyViewModel.value(for: locale)
            )
        }
    }

    private func createEstimationViewModel(
        for chain: Chain,
        commonData: StakingStateCommonData,
        amount: Decimal?
    )
        throws -> StakingEstimationViewModel {
        let balanceViewModelFactory = getBalanceViewModelFactory(for: chain)

        let balance = convertAmount(
            commonData.accountInfo?.data.available,
            for: chain,
            defaultValue: 0.0
        )

        let balanceViewModel = balanceViewModelFactory
            .createAssetBalanceViewModel(
                amount ?? 0.0,
                balance: balance,
                priceData: commonData.price
            )

        let reward: LocalizableResource<PeriodRewardViewModel>? = try createPeriodReward(
            for: chain,
            commonData: commonData,
            amount: amount
        )

        let asset = primitiveFactory.createAssetForAddressType(chain.addressType)

        return StakingEstimationViewModel(
            assetBalance: balanceViewModel,
            rewardViewModel: reward,
            asset: asset,
            inputLimit: StakingConstants.maxAmount,
            amount: amount
        )
    }

    private func stakingAlert(state: NominatorState) -> StakingAlert? {
        switch state.status {
        case .active:
            return nil
        case .inactive:
            guard let minimalStake = state.commonData.minimalStake else {
                return nil
            }
            return .nominatorLowStake(minimalStake: minimalStake)
        // TODO: handle
//            return state.ledgerInfo.active < minimalStake ?
//                .nominatorLowStake(minimalStake: minimalStake)
//                : .nominatorNoValidators
        case .waiting:
            return nil
        case .election:
            return nil
        case .undefined:
            return nil
        }
    }
}

extension StakingStateViewModelFactory: StakingStateVisitorProtocol {
    func visit(state: InitialStakingState) {
        logger?.debug("Initial state")

        guard let chain = state.commonData.chain else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChain(chain)

        lastViewModel = .undefined
    }

    func visit(state: NoStashState) {
        logger?.debug("No stash state")

        guard let chain = state.commonData.chain else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChain(chain)

        do {
            let viewModel = try createEstimationViewModel(
                for: chain,
                commonData: state.commonData,
                amount: state.rewardEstimationAmount
            )

            lastViewModel = .noStash(viewModel: viewModel)
        } catch {
            lastViewModel = .undefined
        }
    }

    func visit(state: StashState) {
        logger?.debug("Stash state")

        guard let chain = state.commonData.chain else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChain(chain)

        lastViewModel = .undefined
    }

    func visit(state: PendingBondedState) {
        logger?.debug("Pending bonded state")

        guard let chain = state.commonData.chain else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChain(chain)

        lastViewModel = .undefined
    }

    func visit(state: BondedState) {
        logger?.debug("Bonded state")

        guard let chain = state.commonData.chain else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChain(chain)

        do {
            let viewModel = try createEstimationViewModel(
                for: chain,
                commonData: state.commonData,
                amount: state.rewardEstimationAmount ?? 0.0
            )

            lastViewModel = .noStash(viewModel: viewModel)
        } catch {
            lastViewModel = .undefined
        }
    }

    func visit(state: PendingNominatorState) {
        logger?.debug("Pending nominator state")

        guard let chain = state.commonData.chain else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChain(chain)

        lastViewModel = .undefined
    }

    func visit(state: NominatorState) {
        logger?.debug("Nominator state")

        guard let chain = state.commonData.chain else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChain(chain)

        let viewModel = createNominationViewModel(
            for: chain,
            commonData: state.commonData,
            state: state,
            viewStatus: state.status
        )

        let alerts = [stakingAlert(state: state)].compactMap { $0 }
        lastViewModel = .nominator(viewModel: viewModel, alerts: alerts)
    }

    func visit(state: PendingValidatorState) {
        logger?.debug("Pending validator")

        guard let chain = state.commonData.chain else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChain(chain)

        lastViewModel = .undefined
    }

    func visit(state: ValidatorState) {
        logger?.debug("Validator state")

        guard let chain = state.commonData.chain else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChain(chain)

        let viewModel = createValidationViewModel(
            for: chain,
            commonData: state.commonData,
            state: state,
            viewStatus: state.status
        )

        lastViewModel = .validator(viewModel: viewModel)
    }
}

extension StakingStateViewModelFactory: StakingStateViewModelFactoryProtocol {
    func createViewModel(from state: StakingStateProtocol) -> StakingViewState {
        state.accept(visitor: self)
        return lastViewModel
    }
}
