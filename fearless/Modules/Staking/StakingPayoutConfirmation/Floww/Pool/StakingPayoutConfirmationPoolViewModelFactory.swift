import Foundation
import FearlessUtils
import SoraFoundation

final class StakingPayoutConfirmationPoolViewModelFactory {
    private let chainAsset: ChainAsset
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private var iconGenerator: IconGenerating
    private lazy var formatterFactory = AssetBalanceFormatterFactory()

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

    func createStakedAmountViewModel(
        _ amount: Decimal
    ) -> LocalizableResource<StakeAmountViewModel>? {
        let localizableBalanceFormatter = formatterFactory.createTokenFormatter(for: chainAsset.assetDisplayInfo, usageCase: .detailsCrypto)

        let iconViewModel = chainAsset.assetDisplayInfo.icon.map { RemoteImageViewModel(url: $0) }

        return LocalizableResource { [weak self] locale in
            let amountString = localizableBalanceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
            let stakedString = R.string.localizable.poolStakingClaimAmountTitle(
                amountString,
                preferredLanguages: locale.rLanguages
            )
            let stakedAmountAttributedString = NSMutableAttributedString(string: stakedString)
            stakedAmountAttributedString.addAttribute(
                NSAttributedString.Key.foregroundColor,
                value: R.color.colorWhite() as Any,
                range: (stakedString as NSString).range(of: amountString)
            )

            return StakeAmountViewModel(
                amountTitle: stakedAmountAttributedString,
                iconViewModel: iconViewModel,
                color: self?.chainAsset.asset.color
            )
        }
    }
}

extension StakingPayoutConfirmationPoolViewModelFactory: StakingPayoutConfirmationViewModelFactoryProtocol {
    func createPayoutConfirmViewModel(
        viewModelState _: StakingPayoutConfirmationViewModelState,
        priceData _: PriceData?
    ) -> [LocalizableResource<PayoutConfirmViewModel>] {
        []
    }

    func createSinglePayoutConfirmationViewModel(
        viewModelState: StakingPayoutConfirmationViewModelState,
        priceData _: PriceData?
    ) -> StakingPayoutConfirmationViewModel? {
        guard let viewModelState = viewModelState as? StakingPayoutConfirmationPoolViewModelState else {
            return nil
        }

        let formatter = formatterFactory.createTokenFormatter(for: chainAsset.asset.displayInfo, usageCase: .detailsCrypto)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).stringFromDecimal(viewModelState.rewardAmount) ?? ""
        }

        return StakingPayoutConfirmationViewModel(
            senderAddress: viewModelState.account?.toAddress() ?? "",
            senderIcon: nil,
            senderName: viewModelState.account?.name,
            amount: createStakedAmountViewModel(viewModelState.rewardAmount),
            amountString: amount
        )
    }
}
