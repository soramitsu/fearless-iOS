import Foundation
import FearlessUtils
import CommonWallet
import SoraFoundation

protocol StakingPayoutConfirmViewModelFactoryProtocol {
    func createPayoutConfirmViewModel(
        with account: AccountItem,
        rewardAmount: Decimal,
        rewardDestination: RewardDestination<DisplayAddress>?,
        priceData: PriceData?
    ) -> [LocalizableResource<PayoutConfirmViewModel>]
}

final class StakingPayoutConfirmViewModelFactory {
    private let asset: WalletAsset
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private lazy var iconGenerator = PolkadotIconGenerator()
    private lazy var amountFactory = AmountFormatterFactory()

    init(
        asset: WalletAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.asset = asset
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    // MARK: - Private functions

    private func createAccountRow(with account: AccountItem) -> LocalizableResource<PayoutConfirmViewModel> {
        let userIcon = try? iconGenerator.generateFromAddress(account.address)
            .imageWithFillColor(
                .white,
                size: UIConstants.smallAddressIconSize,
                contentScale: UIScreen.main.scale
            )

        return LocalizableResource { locale in
            let title = R.string.localizable
                .accountInfoTitle(preferredLanguages: locale.rLanguages)

            return .accountInfo(.init(
                title: title,
                name: account.username,
                icon: userIcon
            ))
        }
    }

    private func createRewardDestinationAccountRow(
        with displayAddress: DisplayAddress
    ) -> LocalizableResource<PayoutConfirmViewModel> {
        let userIcon = try? iconGenerator.generateFromAddress(displayAddress.address)
            .imageWithFillColor(
                .white,
                size: UIConstants.smallAddressIconSize,
                contentScale: UIScreen.main.scale
            )

        return LocalizableResource { locale in
            let title = R.string.localizable
                .stakingRewardDestinationTitle(preferredLanguages: locale.rLanguages)

            let name = displayAddress.username.isEmpty ? displayAddress.address
                : displayAddress.username

            return .accountInfo(.init(
                title: title,
                name: name,
                icon: userIcon
            ))
        }
    }

    private func createRewardDestinationRestakeRow() -> LocalizableResource<PayoutConfirmViewModel> {
        LocalizableResource { locale in
            let title = R.string.localizable.stakingRewardDestinationTitle(preferredLanguages: locale.rLanguages)
            let subtitle = R.string.localizable.stakingRestakeTitle(preferredLanguages: locale.rLanguages)

            return .restakeDestination(.init(title: title, subtitle: subtitle))
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

            return .rewardAmountViewModel(.init(title: title, priceData: priceData.value(for: locale)))
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

extension StakingPayoutConfirmViewModelFactory: StakingPayoutConfirmViewModelFactoryProtocol {
    func createPayoutConfirmViewModel
    (
        with account: AccountItem,
        rewardAmount: Decimal,
        rewardDestination: RewardDestination<DisplayAddress>?,
        priceData: PriceData?
    )
        -> [LocalizableResource<PayoutConfirmViewModel>] {
        var viewModel: [LocalizableResource<PayoutConfirmViewModel>] = []

        viewModel.append(createAccountRow(with: account))

        if let rewardDestination = rewardDestination {
            viewModel.append(createRewardDestinationRow(with: rewardDestination))
        }

        viewModel.append(createRewardAmountRow(with: rewardAmount, priceData: priceData))

        return viewModel
    }
}
