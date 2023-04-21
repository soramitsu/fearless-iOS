import Foundation
import SSFUtils
import SoraFoundation

final class StakingPayoutConfirmationRelaychainViewModelFactory {
    private let chainAsset: ChainAsset
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private var iconGenerator: IconGenerating

    init(
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        iconGenerator: IconGenerating
    ) {
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.iconGenerator = iconGenerator
    }

    // MARK: - Private functions

    private func createAccountRow(with account: ChainAccountResponse) -> LocalizableResource<PayoutConfirmViewModel> {
        let address = (try? AddressFactory.address(for: account.accountId, chain: chainAsset.chain)) ?? ""
        let userIcon = try? iconGenerator.generateFromAddress(address)
            .imageWithFillColor(
                R.color.colorWhite()!,
                size: UIConstants.smallAddressIconSize,
                contentScale: UIScreen.main.scale
            )

        return LocalizableResource { locale in
            let title = R.string.localizable
                .accountInfoTitle(preferredLanguages: locale.rLanguages)

            return .accountInfo(.init(
                title: title,
                address: address,
                name: account.name,
                icon: userIcon
            ))
        }
    }

    private func createRewardDestinationAccountRow(
        with displayAddress: DisplayAddress
    ) -> LocalizableResource<PayoutConfirmViewModel> {
        let userIcon = try? iconGenerator.generateFromAddress(displayAddress.address)
            .imageWithFillColor(
                R.color.colorWhite()!,
                size: UIConstants.smallAddressIconSize,
                contentScale: UIScreen.main.scale
            )

        return LocalizableResource { locale in
            let title = R.string.localizable
                .stakingRewardsDestinationTitle(preferredLanguages: locale.rLanguages)

            let name = displayAddress.username.isEmpty ? displayAddress.address
                : displayAddress.username

            return .accountInfo(.init(
                title: title,
                address: displayAddress.address,
                name: name,
                icon: userIcon
            ))
        }
    }

    private func createRewardDestinationRestakeRow() -> LocalizableResource<PayoutConfirmViewModel> {
        LocalizableResource { locale in
            let title = R.string.localizable.stakingRewardsDestinationTitle(preferredLanguages: locale.rLanguages)
            let subtitle = R.string.localizable.stakingRestakeTitle(preferredLanguages: locale.rLanguages)

            return .restakeDestination(.init(titleText: title, valueText: subtitle))
        }
    }

    private func createRewardAmountRow
    (
        with amount: Decimal,
        priceData: PriceData?
    )
        -> LocalizableResource<PayoutConfirmViewModel> {
        LocalizableResource { locale in

            let title = R.string.localizable
                .stakingReward(preferredLanguages: locale.rLanguages)

            let priceData = self.balanceViewModelFactory.balanceFromPrice(amount, priceData: priceData)

            let reward = priceData.value(for: locale)

            return .rewardAmountViewModel(
                .init(
                    title: title,
                    tokenAmountText: reward.amount,
                    usdAmountText: reward.price
                )
            )
        }
    }

    private func createRewardDestinationRow(
        with rewardDestination: RewardDestination<DisplayAddress>) -> LocalizableResource<PayoutConfirmViewModel> {
        switch rewardDestination {
        case .restake:
            return createRewardDestinationRestakeRow()
        case let .payout(account):
            return createRewardDestinationAccountRow(with: account)
        }
    }
}

extension StakingPayoutConfirmationRelaychainViewModelFactory: StakingPayoutConfirmationViewModelFactoryProtocol {
    func createPayoutConfirmViewModel(
        viewModelState: StakingPayoutConfirmationViewModelState,
        priceData: PriceData?
    ) -> [LocalizableResource<PayoutConfirmViewModel>] {
        guard let relaychainViewModelState = viewModelState as? StakingPayoutConfirmationRelaychainViewModelState else {
            return []
        }

        var viewModel: [LocalizableResource<PayoutConfirmViewModel>] = []

        if let account = relaychainViewModelState.account {
            viewModel.append(createAccountRow(with: account))
        }

        if let rewardDestination = relaychainViewModelState.rewardDestination {
            viewModel.append(createRewardDestinationRow(with: rewardDestination))
        }

        viewModel.append(createRewardAmountRow(with: relaychainViewModelState.rewardAmount, priceData: priceData))

        return viewModel
    }

    func createSinglePayoutConfirmationViewModel(
        viewModelState _: StakingPayoutConfirmationViewModelState,
        priceData _: PriceData?
    ) -> StakingPayoutConfirmationViewModel? {
        nil
    }
}
