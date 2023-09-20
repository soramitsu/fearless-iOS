import Foundation
import SoraFoundation
import BigInt
import SSFModels

final class StakingBalanceParachainViewModelFactory: StakingBalanceViewModelFactoryProtocol {
    private let chainAsset: ChainAsset
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let timeFormatter: TimeFormatterProtocol

    init(
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        timeFormatter: TimeFormatterProtocol
    ) {
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.timeFormatter = timeFormatter
    }

    func buildViewModel(
        viewModelState: StakingBalanceViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<StakingBalanceViewModel>? {
        guard let viewModelState = viewModelState as? StakingBalanceParachainViewModelState else {
            return nil
        }

        return LocalizableResource { [unowned self] locale in
            let precision = Int16(self.chainAsset.asset.precision)

            let redeemableDecimal = Decimal.fromSubstrateAmount(
                viewModelState.calculateRevokeAmount() ?? BigUInt.zero,
                precision: precision
            ) ?? 0.0

            let bondedDecimal = Decimal.fromSubstrateAmount(
                viewModelState.delegation?.amount ?? BigUInt.zero,
                precision: precision
            ) ?? 0.0

            let unbondedDecimal = Decimal.fromSubstrateAmount(
                calculateDecreaseAmount(viewModelState: viewModelState, currentEra: viewModelState.round?.current),
                precision: precision
            ) ?? 0.0

            let widgetViewModel = self.createWidgetViewModel(
                from: viewModelState,
                precision: precision,
                redeemableDecimal: redeemableDecimal,
                locale: locale,
                priceData: priceData
            )

            let unbondingViewModel = self.createUnbondingViewModel(
                viewModelState: viewModelState,
                priceData: priceData,
                precision: precision,
                locale: locale
            )

            return StakingBalanceViewModel(
                title: viewModelState.collator.identity?.name,
                widgetViewModel: widgetViewModel,
                actionsViewModel: self.createActionsViewModel(
                    redeemableDecimal: redeemableDecimal,
                    bondedDecimal: bondedDecimal,
                    unbondedDecimal: unbondedDecimal,
                    locale: locale
                ),
                unbondingViewModel: unbondingViewModel
            )
        }
    }

    func createWidgetViewModel(
        from viewModelState: StakingBalanceParachainViewModelState,
        precision: Int16,
        redeemableDecimal: Decimal,
        locale: Locale,
        priceData: PriceData?
    ) -> StakingBalanceWidgetViewModel {
        let bondedDecimal = Decimal.fromSubstrateAmount(
            viewModelState.delegation?.amount ?? BigUInt.zero,
            precision: precision
        ) ?? 0.0
        let bondedViewModel = createWidgetItemViewModel(
            amount: bondedDecimal,
            title: R.string.localizable.walletBalanceBonded(preferredLanguages: locale.rLanguages),
            priceData: priceData,
            locale: locale
        )

        let unbondedDecimal = Decimal.fromSubstrateAmount(
            calculateDecreaseAmount(viewModelState: viewModelState, currentEra: viewModelState.round?.current),
            precision: precision
        ) ?? 0.0
        let unbondedViewModel = createWidgetItemViewModel(
            amount: unbondedDecimal,
            title: R.string.localizable.walletBalanceUnbonding_v190(preferredLanguages: locale.rLanguages),
            priceData: priceData,
            locale: locale
        )

        let redeemableViewModel = createWidgetItemViewModel(
            amount: redeemableDecimal,
            title: R.string.localizable.parachainStakingReadyForRevoking(preferredLanguages: locale.rLanguages),
            priceData: priceData,
            locale: locale
        )

        return StakingBalanceWidgetViewModel(
            title: R.string.localizable.commonBalance(preferredLanguages: locale.rLanguages),
            itemViewModels: [bondedViewModel, unbondedViewModel, redeemableViewModel]
        )
    }

    func createWidgetItemViewModel(
        amount: Decimal,
        title: String,
        priceData: PriceData?,
        locale: Locale
    ) -> StakingBalanceWidgetItemViewModel {
        StakingBalanceWidgetItemViewModel(
            title: title,
            tokenAmountText: tokenAmountText(amount, locale: locale),
            usdAmountText: priceText(amount, priceData: priceData, locale: locale)
        )
    }

    func createActionsViewModel(
        redeemableDecimal: Decimal,
        bondedDecimal: Decimal,
        unbondedDecimal: Decimal,
        locale: Locale
    ) -> StakingBalanceActionsWidgetViewModel {
        StakingBalanceActionsWidgetViewModel(
            bondTitle: StakingBalanceAction.bondMore.title(for: locale),
            unbondTitle: R.string.localizable.parachainStakingStakeLess(preferredLanguages: locale.rLanguages),
            redeemTitle: R.string.localizable.parachainStakingUnlock(preferredLanguages: locale.rLanguages),
            redeemIcon: R.image.iconRevoke(),
            redeemActionIsAvailable: redeemableDecimal > 0,
            stakeMoreActionAvailable: bondedDecimal != unbondedDecimal && redeemableDecimal < bondedDecimal,
            stakeLessActionAvailable: !(unbondedDecimal + redeemableDecimal > 0) && bondedDecimal > 0
        )
    }

    func createUnbondingViewModel(
        viewModelState: StakingBalanceParachainViewModelState,
        priceData: PriceData?,
        precision: Int16,
        locale: Locale
    ) -> StakingBalanceUnbondingWidgetViewModel {
        let viewModels = createUnbondingsViewModels(
            from: viewModelState,
            priceData: priceData,
            precision: precision,
            locale: locale
        )
        return StakingBalanceUnbondingWidgetViewModel(
            title: R.string.localizable
                .stakingHistoryTitle(preferredLanguages: locale.rLanguages),
            emptyListDescription: R.string.localizable
                .stakingUnbondingEmptyList_v190(preferredLanguages: locale.rLanguages),
            unbondings: viewModels
        )
    }

    func createUnbondingsViewModels(
        from viewModelState: StakingBalanceParachainViewModelState,
        priceData: PriceData?,
        precision: Int16,
        locale: Locale
    ) -> [UnbondingItemViewModel] {
        guard let round = viewModelState.round,
              let requests = viewModelState.requests,
              let subqueryData = viewModelState.subqueryData else {
            return []
        }

        let actualViewModels: [UnbondingItemViewModel] = requests.compactMap { request in
            var amount = BigUInt.zero
            var title: String = ""
            if case let .decrease(decreaseAmount) = request.action {
                amount = decreaseAmount
                title = R.string.localizable.stakingUnbond_v190(
                    preferredLanguages: locale.rLanguages
                )
            }
            if case let .revoke(revokeAmount) = request.action {
                amount = revokeAmount
                title = R.string.localizable.parachainStakingRevoke(
                    preferredLanguages: locale.rLanguages
                )
            }
            let unbondingAmountDecimal = Decimal
                .fromSubstrateAmount(
                    amount,
                    precision: precision
                ) ?? .zero
            let tokenAmount = tokenAmountText(unbondingAmountDecimal, locale: locale)
            let usdAmount = priceText(unbondingAmountDecimal, priceData: priceData, locale: locale)
            let timeLeft = timeLeftInterval(
                unbondingRoundIndex: UInt32(request.whenExecutable),
                currentRound: round,
                currentBlock: viewModelState.currentBlock
            )

            return UnbondingItemViewModel(
                addressOrName: title,
                daysLeftText: NSAttributedString(),
                tokenAmountText: tokenAmount,
                usdAmountText: usdAmount,
                timeInterval: timeLeft,
                locale: locale
            )
        }

        let historyViewModels: [UnbondingItemViewModel] = subqueryData.compactMap { unstake in
            let title: String = unstake.type.title(locale: locale) ?? ""

            let unbondingAmountDecimal = Decimal
                .fromSubstrateAmount(
                    unstake.amount,
                    precision: precision
                ) ?? .zero
            let tokenAmount = tokenAmountText(unbondingAmountDecimal, locale: locale)
            let usdAmount = priceText(unbondingAmountDecimal, priceData: priceData, locale: locale)
            let timeLeft = unstake.blockNumber > viewModelState.currentBlock ?? 0 ? timeLeftInterval(
                unbondingRoundIndex: UInt32(unstake.blockNumber),
                currentRound: round,
                currentBlock: viewModelState.currentBlock
            ) : 0

            return UnbondingItemViewModel(
                addressOrName: title,
                daysLeftText: NSAttributedString(),
                tokenAmountText: tokenAmount,
                usdAmountText: usdAmount,
                timeInterval: timeLeft,
                locale: locale
            )
        }

        return actualViewModels + historyViewModels
    }

    private func tokenAmountText(_ value: Decimal, locale: Locale) -> String {
        balanceViewModelFactory.amountFromValue(value, usageCase: .detailsCrypto).value(for: locale)
    }

    private func priceText(_ amount: Decimal, priceData: PriceData?, locale: Locale) -> String? {
        guard let priceData = priceData else {
            return nil
        }

        let price = balanceViewModelFactory
            .priceFromAmount(amount, priceData: priceData).value(for: locale)
        return price
    }

    private func timeLeftInterval(
        unbondingRoundIndex: UInt32?,
        currentRound: ParachainStakingRoundInfo,
        currentBlock: UInt32?
    ) -> TimeInterval? {
        guard let unbondingRoundIndex = unbondingRoundIndex, let currentBlock = currentBlock else {
            return nil
        }

        guard unbondingRoundIndex > currentRound.current else {
            return 0
        }

        let difference = UInt32(abs(Int32(unbondingRoundIndex) - Int32(currentRound.current)))
        let roundDurationInSeconds: TimeInterval = 24.0 / Double(chainAsset.chain.erasPerDay) * 3600.0
        let blockDurationInSeconds: TimeInterval = roundDurationInSeconds / Double(currentRound.length)
        let currentRoundTimeLife: TimeInterval = Double((currentRound.first + currentRound.length) - currentBlock) * blockDurationInSeconds
        let eraCompletionTime = TimeInterval(difference - 1) / TimeInterval(chainAsset.chain.erasPerDay) * 86400.0 + currentRoundTimeLife

        return TimeInterval(eraCompletionTime)
    }

    private func calculateDecreaseAmount(
        viewModelState: StakingBalanceParachainViewModelState,
        currentEra _: EraIndex?
    ) -> BigUInt {
        let amount = viewModelState.history?.compactMap { request in
            var amount = BigUInt.zero
            if case let .revoke(revokeAmount) = request.action {
                amount += revokeAmount
            }

            if case let .decrease(decreaseAmount) = request.action {
                amount += decreaseAmount
            }

            return amount
        }.reduce(BigUInt.zero, +)

        return amount ?? BigUInt.zero
    }

    private func calculateRevokeAmount(
        viewModelState: StakingBalanceParachainViewModelState,
        currentEra: EraIndex?
    ) -> BigUInt {
        let amount = viewModelState.requests?.filter { request in
            guard let currentEra = currentEra else {
                return false
            }

            return request.whenExecutable <= currentEra
        }.compactMap { request in
            var amount = BigUInt.zero
            if case let .revoke(revokeAmount) = request.action {
                amount += revokeAmount
            }

            if case let .decrease(decreaseAmount) = request.action {
                amount += decreaseAmount
            }

            return amount
        }.reduce(BigUInt.zero, +)

        return amount ?? BigUInt.zero
    }
}
