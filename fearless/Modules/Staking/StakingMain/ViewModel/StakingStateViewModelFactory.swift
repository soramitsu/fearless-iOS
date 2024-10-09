import Foundation

import SoraFoundation
import BigInt
import IrohaCrypto
import SoraKeystore
import SSFModels

protocol StakingStateViewModelFactoryProtocol {
    func createViewModel(from state: StakingStateProtocol) -> StakingViewState
}

typealias AnalyticsRewardsViewModelFactoryBuilder = (
    ChainAsset,
    BalanceViewModelFactoryProtocol
) -> AnalyticsRewardsViewModelFactoryProtocol

final class StakingStateViewModelFactory {
    private let analyticsRewardsViewModelFactoryBuilder: AnalyticsRewardsViewModelFactoryBuilder
    private let logger: LoggerProtocol?
    private var selectedMetaAccount: MetaAccountModel
    private let eventCenter: EventCenter

    private var lastViewModel: StakingViewState = .undefined
    private var rewardViewModelFactory: RewardViewModelFactoryProtocol?
    private var cachedChainAsset: ChainAsset?

    init(
        analyticsRewardsViewModelFactoryBuilder: @escaping AnalyticsRewardsViewModelFactoryBuilder,
        logger: LoggerProtocol? = nil,
        selectedMetaAccount: MetaAccountModel,
        eventCenter: EventCenter
    ) {
        self.analyticsRewardsViewModelFactoryBuilder = analyticsRewardsViewModelFactoryBuilder
        self.logger = logger
        self.selectedMetaAccount = selectedMetaAccount
        self.eventCenter = eventCenter
        self.eventCenter.add(observer: self, dispatchIn: .main)
    }

    private func updateCacheForChainAsset(_ newChainAsset: ChainAsset) {
        if newChainAsset != cachedChainAsset {
            rewardViewModelFactory = nil
            cachedChainAsset = newChainAsset
        }
    }

    private func convertAmount(
        _ amount: BigUInt?,
        for chainAsset: ChainAsset,
        defaultValue: Decimal
    ) -> Decimal {
        if let amount = amount {
            return Decimal.fromSubstrateAmount(
                amount,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) ?? defaultValue
        } else {
            return defaultValue
        }
    }

    func getBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactoryProtocol {
        let factory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: selectedMetaAccount
        )

        return factory
    }

    private func getRewardViewModelFactory(for chainAsset: ChainAsset) -> RewardViewModelFactoryProtocol {
        if let factory = rewardViewModelFactory {
            return factory
        }

        let factory = RewardViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: selectedMetaAccount
        )

        rewardViewModelFactory = factory

        return factory
    }

    private func createNominationViewModel(
        for chainAsset: ChainAsset,
        commonData: StakingStateCommonData,
        state: BaseStashNextState,
        ledgerInfo: StakingLedger,
        viewStatus: NominationViewStatus
    ) -> LocalizableResource<NominationViewModelProtocol> {
        let balanceViewModelFactory = getBalanceViewModelFactory(for: chainAsset)
        let rewardBalanceViewModelFactory = getBalanceViewModelFactory(for: commonData.rewardChainAsset ?? chainAsset)

        let stakedAmount = convertAmount(ledgerInfo.active, for: chainAsset, defaultValue: 0.0)
        let priceData = commonData.chainAsset?.asset.getPrice(for: selectedMetaAccount.selectedCurrency)
        let staked = balanceViewModelFactory.balanceFromPrice(
            stakedAmount,
            priceData: priceData,
            usageCase: .listCrypto
        )

        let rewardPriceData = commonData.rewardChainAsset?.asset.getPrice(for: selectedMetaAccount.selectedCurrency)
        let rewardPrice = rewardPriceData ?? priceData

        let reward: LocalizableResource<BalanceViewModelProtocol>?
        if let totalReward = state.totalReward {
            reward = rewardBalanceViewModelFactory.balanceFromPrice(
                totalReward.amount.decimalValue,
                priceData: rewardPrice,
                usageCase: .listCrypto
            )
        } else {
            reward = nil
        }

        return LocalizableResource { locale in
            let defaultReward: String = (chainAsset.chain.externalApi?.staking == nil) ? R.string.localizable.commonNotAvailableShort(preferredLanguages: locale.rLanguages) : ""
            let stakedViewModel = staked.value(for: locale)
            let rewardViewModel = reward?.value(for: locale)

            return NominationViewModel(
                totalStakedAmount: stakedViewModel.amount,
                totalStakedPrice: stakedViewModel.price ?? "",
                totalRewardAmount: rewardViewModel?.amount ?? defaultReward,
                totalRewardPrice: rewardViewModel?.price ?? "",
                status: viewStatus,
                hasPrice: priceData != nil,
                rewardViewTitle: R.string.localizable
                    .stakingTotalRewards_v190(preferredLanguages: locale.rLanguages)
            )
        }
    }

    private func createValidationViewModel(
        for chainAsset: ChainAsset,
        commonData: StakingStateCommonData,
        state: ValidatorState,
        viewStatus: ValidationViewStatus
    ) -> LocalizableResource<ValidationViewModelProtocol> {
        let balanceViewModelFactory = getBalanceViewModelFactory(for: chainAsset)

        let stakedAmount = convertAmount(state.ledgerInfo.active, for: chainAsset, defaultValue: 0.0)
        let priceData = commonData.chainAsset?.asset.getPrice(for: selectedMetaAccount.selectedCurrency)
        let staked = balanceViewModelFactory.balanceFromPrice(
            stakedAmount,
            priceData: priceData,
            usageCase: .listCrypto
        )

        let reward: LocalizableResource<BalanceViewModelProtocol>?
        if let totalReward = state.totalReward {
            reward = balanceViewModelFactory.balanceFromPrice(
                totalReward.amount.decimalValue,
                priceData: priceData,
                usageCase: .listCrypto
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
                status: viewStatus,
                hasPrice: priceData != nil
            )
        }
    }

    private func createDelegationViewModels(
        state: ParachainState,
        chainAsset: ChainAsset,
        countdownInterval: TimeInterval?
    ) -> [DelegationInfoCellModel]? {
        let balanceViewModelFactory = getBalanceViewModelFactory(for: chainAsset)
        let models: [DelegationInfoCellModel]? = state.delegationInfos?.compactMap { [weak self] delegationInfo in
            guard let self = self else { return nil }
            let collator = delegationInfo.collator
            let delegation = delegationInfo.delegation

            let resource: LocalizableResource<DelegationViewModelProtocol> = LocalizableResource { locale in
                var status: DelegationViewStatus
                switch collator.metadata?.status {
                case .active:
                    status = .active(round: state.round?.current ?? 0)
                case .idle:
                    status = .idle(countdown: countdownInterval)
                case .leaving:
                    status = .leaving(countdown: countdownInterval)
                case .none:
                    status = .undefined
                }

                if let bottomDelegations = state.bottomDelegations,
                   let collatorBottomDelegations = bottomDelegations[collator.address] {
                    if collatorBottomDelegations.delegations.contains(where: { $0 == delegation }) {
                        status = .lowStake
                    }
                }

                if let accountId = try? state.commonData.address?.toAccountId(using: chainAsset.chain.chainFormat),
                   let round = state.round,
                   let requests = state.requests {
                    if requests.contains(where: { requestsByCollatorAddress in
                        let ownOutdatedRequests = requestsByCollatorAddress.value
                            .filter { $0.delegator == accountId }
                            .filter { $0.whenExecutable <= round.current }
                        let amount: BigUInt = ownOutdatedRequests.compactMap { ownRequest in
                            var amount = BigUInt.zero
                            if case let .revoke(revokeAmount) = ownRequest.action {
                                amount += revokeAmount
                            }

                            if case let .decrease(decreaseAmount) = ownRequest.action {
                                amount += decreaseAmount
                            }

                            return amount
                        }.reduce(BigUInt.zero, +)

                        if amount > BigUInt.zero {
                            return collator.address == requestsByCollatorAddress.key
                        }
                        return false
                    }) {
                        status = .readyToUnlock
                    }
                }

                let amount = Decimal.fromSubstrateAmount(
                    delegation.amount,
                    precision: Int16(chainAsset.asset.precision)
                ) ?? Decimal.zero
                let apyFormatter = NumberFormatter.percentPlain.localizableResource().value(for: locale)
                let priceData = state.commonData.chainAsset?.asset.getPrice(for: self.selectedMetaAccount.selectedCurrency)
                return DelegationViewModel(
                    totalStakedAmount: balanceViewModelFactory.amountFromValue(amount, usageCase: .listCrypto).value(for: locale),
                    totalStakedPrice: balanceViewModelFactory.balanceFromPrice(
                        amount,
                        priceData: priceData,
                        usageCase: .listCrypto
                    ).value(for: locale).price ?? "",
                    apr: apyFormatter.string(from: (collator.subqueryData?.apr ?? 0.0) as NSNumber) ?? "",
                    status: status,
                    hasPrice: true,
                    name: collator.identity?.name,
                    nextRoundInterval: countdownInterval
                )
            }
            return DelegationInfoCellModel(
                contentViewModel: resource,
                delegationInfo: delegationInfo
            )
        }
        return models
    }

    private func createAnalyticsViewModel(
        commonData: StakingStateCommonData,
        chainAsset: ChainAsset
    ) -> LocalizableResource<RewardAnalyticsWidgetViewModel>? {
        guard let rewardsForPeriod = commonData.subqueryRewards, let rewards = rewardsForPeriod.0 else {
            return nil
        }
        let balanceViewModelFactory = getBalanceViewModelFactory(for: chainAsset)

        let analyticsViewModelFactory = analyticsRewardsViewModelFactoryBuilder(chainAsset, balanceViewModelFactory)
        let priceData = commonData.chainAsset?.asset.getPrice(for: selectedMetaAccount.selectedCurrency)
        let fullViewModel = analyticsViewModelFactory.createViewModel(
            from: rewards,
            priceData: priceData,
            period: rewardsForPeriod.1,
            selectedChartIndex: nil,
            hasPendingRewards: chainAsset.stakingType?.isRelaychain == true
        )
        return LocalizableResource { locale in
            RewardAnalyticsWidgetViewModel(
                summary: fullViewModel.value(for: locale).summaryViewModel,
                chartData: fullViewModel.value(for: locale).chartData
            )
        }
    }

    private func createPeriodReward(
        for chainAsset: ChainAsset,
        commonData: StakingStateCommonData,
        amount: Decimal?
    ) throws -> LocalizableResource<PeriodRewardViewModel>? {
        guard let calculator = commonData.calculatorEngine else {
            return nil
        }
        let chainAsset = commonData.rewardChainAsset ?? chainAsset
        let priceData = commonData.chainAsset?.asset.getPrice(for: selectedMetaAccount.selectedCurrency)
        let rewardPriceData = commonData.rewardChainAsset?.asset.getPrice(for: selectedMetaAccount.selectedCurrency)
        let price = rewardPriceData ?? priceData

        let rewardViewModelFactory = getRewardViewModelFactory(for: chainAsset)

        let monthlyReturn = calculator.calculatorReturn(isCompound: true, period: .month, type: .max())
        let yearlyReturn = calculator.calculatorReturn(isCompound: true, period: .year, type: .max())

        let rewardAssetRate = calculator.rewardAssetRate
        let yearlyReturnAmount = yearlyReturn * (amount ?? 1.0) * rewardAssetRate
        let monthlyReturnAmount = monthlyReturn * (amount ?? 1.0) * rewardAssetRate

        let monthlyViewModel = rewardViewModelFactory.createRewardViewModel(
            reward: monthlyReturnAmount,
            targetReturn: monthlyReturn,
            priceData: price
        )

        let yearlyViewModel = rewardViewModelFactory.createRewardViewModel(
            reward: yearlyReturnAmount,
            targetReturn: yearlyReturn,
            priceData: price
        )

        return LocalizableResource { locale in
            PeriodRewardViewModel(
                monthlyReward: monthlyViewModel.value(for: locale),
                yearlyReward: yearlyViewModel.value(for: locale)
            )
        }
    }

    private func createEstimationViewModel(
        for chainAsset: ChainAsset,
        commonData: StakingStateCommonData,
        amount: Decimal?
    ) throws -> StakingEstimationViewModel {
        let balanceViewModelFactory = getBalanceViewModelFactory(for: chainAsset)

        let balance = convertAmount(
            commonData.accountInfo?.data.stakingAvailable,
            for: chainAsset,
            defaultValue: 0.0
        )
        let priceData = commonData.chainAsset?.asset.getPrice(for: selectedMetaAccount.selectedCurrency)
        let balanceViewModel = balanceViewModelFactory
            .createAssetBalanceViewModel(
                amount ?? 0.0,
                balance: balance,
                priceData: priceData
            )

        let reward: LocalizableResource<PeriodRewardViewModel>? = try createPeriodReward(
            for: chainAsset,
            commonData: commonData,
            amount: amount
        )

        return StakingEstimationViewModel(
            assetBalance: balanceViewModel,
            rewardViewModel: reward,
            assetInfo: chainAsset.assetDisplayInfo,
            inputLimit: StakingConstants.maxAmount,
            amount: amount
        )
    }
}

extension StakingStateViewModelFactory: StakingStateVisitorProtocol {
    func visit(state: InitialRelaychainStakingState) {
        logger?.debug("Initial state")

        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChainAsset(chainAsset)

        lastViewModel = .undefined
    }

    func visit(state: NoStashState) {
        logger?.debug("No stash state")

        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChainAsset(chainAsset)

        do {
            let viewModel = try createEstimationViewModel(
                for: chainAsset,
                commonData: state.commonData,
                amount: state.rewardEstimationAmount
            )

            let alerts = stakingAlertsNoStashState(state)
            lastViewModel = .noStash(viewModel: viewModel, alerts: alerts)
        } catch {
            lastViewModel = .undefined
        }
    }

    func visit(state: StashState) {
        logger?.debug("Stash state")

        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChainAsset(chainAsset)

        lastViewModel = .undefined
    }

    func visit(state: PendingBondedState) {
        logger?.debug("Pending bonded state")

        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChainAsset(chainAsset)

        lastViewModel = .undefined
    }

    func visit(state: BondedState) {
        logger?.debug("Bonded state")

        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChainAsset(chainAsset)

        let status: NominationViewStatus = {
            if let era = state.commonData.eraStakersInfo?.activeEra {
                return .inactive(era: era)
            } else {
                return .undefined
            }
        }()

        let viewModel = createNominationViewModel(
            for: chainAsset,
            commonData: state.commonData,
            state: state,
            ledgerInfo: state.ledgerInfo,
            viewStatus: status
        )

        let analyticsViewModel = createAnalyticsViewModel(
            commonData: state.commonData,
            chainAsset: chainAsset
        )

        let alerts = stakingAlertsForBondedState(state)
        lastViewModel = .nominator(
            viewModel: viewModel,
            alerts: alerts,
            analyticsViewModel: analyticsViewModel
        )
    }

    func visit(state: PendingNominatorState) {
        logger?.debug("Pending nominator state")

        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChainAsset(chainAsset)

        lastViewModel = .undefined
    }

    func visit(state: NominatorState) {
        logger?.debug("Nominator state")

        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChainAsset(chainAsset)

        let viewModel = createNominationViewModel(
            for: chainAsset,
            commonData: state.commonData,
            state: state,
            ledgerInfo: state.ledgerInfo,
            viewStatus: state.status
        )

        let analyticsViewModel = createAnalyticsViewModel(
            commonData: state.commonData,
            chainAsset: chainAsset
        )

        let alerts = stakingAlertsForNominatorState(state)
        lastViewModel = .nominator(
            viewModel: viewModel,
            alerts: alerts,
            analyticsViewModel: analyticsViewModel
        )
    }

    func visit(state: PendingValidatorState) {
        logger?.debug("Pending validator")

        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChainAsset(chainAsset)

        lastViewModel = .undefined
    }

    func visit(state: ValidatorState) {
        logger?.debug("Validator state")

        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChainAsset(chainAsset)

        let viewModel = createValidationViewModel(
            for: chainAsset,
            commonData: state.commonData,
            state: state,
            viewStatus: state.status
        )

        let alerts = stakingAlertsForValidatorState(state)
        let analyticsViewModel = createAnalyticsViewModel(
            commonData: state.commonData,
            chainAsset: chainAsset
        )
        lastViewModel = .validator(viewModel: viewModel, alerts: alerts, analyticsViewModel: analyticsViewModel)
    }

    func visit(state: ParachainState) {
        logger?.debug("Parachain state")

        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChainAsset(chainAsset)

        var countdownInterval: TimeInterval?
        let erasPerDay = chainAsset.chain.erasPerDay
        if let round = state.round, let currentBlock = state.currentBlock {
            let roundDurationInSeconds: TimeInterval = 24.0 / Double(erasPerDay) * 3600.0
            let blockDurationInSeconds: TimeInterval = roundDurationInSeconds / Double(round.length)
            let countdown: TimeInterval = Double((round.first + round.length) - currentBlock) * blockDurationInSeconds
            countdownInterval = countdown
        }

        let delegationViewModels = createDelegationViewModels(
            state: state,
            chainAsset: chainAsset,
            countdownInterval: countdownInterval
        )

        let analyticsViewModel = createAnalyticsViewModel(
            commonData: state.commonData,
            chainAsset: chainAsset
        )

        let alerts = stakingAlertParachainState(state)
        do {
            let rewardViewModel = try createEstimationViewModel(
                for: chainAsset,
                commonData: state.commonData,
                amount: state.rewardEstimationAmount
            )
            lastViewModel = .delegations(
                rewardViewModel: rewardViewModel,
                delegationViewModels: delegationViewModels,
                alerts: alerts,
                analyticsViewModel: analyticsViewModel
            )
        } catch {
            lastViewModel = .undefined
        }
    }
}

extension StakingStateViewModelFactory: StakingStateViewModelFactoryProtocol {
    func createViewModel(from state: StakingStateProtocol) -> StakingViewState {
        state.accept(visitor: self)
        return lastViewModel
    }
}

extension StakingStateViewModelFactory: EventVisitorProtocol {
    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        selectedMetaAccount = event.account
    }
}
