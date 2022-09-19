import Foundation
import FearlessUtils
import SoraFoundation

final class StakingUnbondConfirmPoolViewModelFactory: StakingUnbondConfirmViewModelFactoryProtocol {
    let asset: AssetModel

    private lazy var formatterFactory = AssetBalanceFormatterFactory()
    private var iconGenerator: IconGenerating

    init(
        asset: AssetModel,
        iconGenerator: IconGenerating
    ) {
        self.asset = asset
        self.iconGenerator = iconGenerator
    }

    private func createHints(from _: Bool)
        -> LocalizableResource<[TitleIconViewModel]> {
        LocalizableResource { locale in
            var items = [TitleIconViewModel]()

            items.append(
                TitleIconViewModel(
                    title: R.string.localizable.stakingHintNoRewards(preferredLanguages: locale.rLanguages),
                    icon: R.image.iconNoReward()
                )
            )

            return items
        }
    }

    func buildViewModel(viewModelState: StakingUnbondConfirmViewModelState) -> StakingUnbondConfirmViewModel? {
        guard let viewModelState = viewModelState as? StakingUnbondConfirmPoolViewModelState else {
            return nil
        }

        let formatter = formatterFactory.createTokenFormatter(for: asset.displayInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).stringFromDecimal(viewModelState.inputAmount) ?? ""
        }

        let address = viewModelState.accountAddress ?? ""
        let accountIcon = try? iconGenerator.generateFromAddress(address)

        let hints = createHints(from: false)

        return StakingUnbondConfirmViewModel(
            senderAddress: address,
            senderIcon: accountIcon,
            senderName: viewModelState.wallet.fetch(for: viewModelState.chainAsset.chain.accountRequest())?.name,
            collatorName: nil,
            collatorIcon: nil,
            stakeAmountViewModel: createStakedAmountViewModel(viewModelState.inputAmount),
            amountString: amount,
            hints: hints
        )
    }

    func buildBondingDurationViewModel(
        viewModelState _: StakingUnbondConfirmViewModelState
    ) -> LocalizableResource<TitleWithSubtitleViewModel>? {
        nil
    }

    func createStakedAmountViewModel(
        _ amount: Decimal
    ) -> LocalizableResource<StakeAmountViewModel>? {
        let localizableBalanceFormatter = formatterFactory.createTokenFormatter(for: asset.displayInfo)

        let iconViewModel = asset.displayInfo.icon.map { RemoteImageViewModel(url: $0) }

        return LocalizableResource { locale in
            let amountString = localizableBalanceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
            let stakedString = R.string.localizable.poolStakingUnstakeAmountTitle(
                amountString,
                preferredLanguages: locale.rLanguages
            )
            let stakedAmountAttributedString = NSMutableAttributedString(string: stakedString)
            stakedAmountAttributedString.addAttribute(
                NSAttributedString.Key.foregroundColor,
                value: R.color.colorWhite(),
                range: (stakedString as NSString).range(of: amountString)
            )

            return StakeAmountViewModel(amountTitle: stakedAmountAttributedString, iconViewModel: iconViewModel)
        }
    }
}
