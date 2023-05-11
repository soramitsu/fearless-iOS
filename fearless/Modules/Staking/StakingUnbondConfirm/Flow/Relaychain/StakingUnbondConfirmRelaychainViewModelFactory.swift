import Foundation
import SSFUtils
import SoraFoundation

final class StakingUnbondConfirmRelaychainViewModelFactory: StakingUnbondConfirmViewModelFactoryProtocol {
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

    private func createHints(from shouldResetRewardDestination: Bool)
        -> LocalizableResource<[TitleIconViewModel]> {
        LocalizableResource { locale in
            var items = [TitleIconViewModel]()

            items.append(
                TitleIconViewModel(
                    title: R.string.localizable.stakingHintNoRewards(preferredLanguages: locale.rLanguages),
                    icon: R.image.iconNoReward()
                )
            )

            if shouldResetRewardDestination {
                items.append(
                    TitleIconViewModel(
                        title: R.string.localizable.stakingHintUnbondKillsStash(
                            preferredLanguages: locale.rLanguages
                        ),
                        icon: R.image.iconWallet()
                    )
                )
            }

            items.append(
                TitleIconViewModel(
                    title: R.string.localizable.stakingHintRedeem(
                        preferredLanguages: locale.rLanguages
                    ),
                    icon: R.image.iconRedeem()
                )
            )

            return items
        }
    }

    func buildViewModel(viewModelState: StakingUnbondConfirmViewModelState) -> StakingUnbondConfirmViewModel? {
        guard let viewModelState = viewModelState as? StakingUnbondConfirmRelaychainViewModelState,
              let controller = viewModelState.controller else {
            return nil
        }

        let formatter = formatterFactory.createTokenFormatter(for: asset.displayInfo, usageCase: .detailsCrypto)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).stringFromDecimal(viewModelState.inputAmount) ?? ""
        }

        let address = controller.toAddress() ?? ""
        let icon = try? iconGenerator.generateFromAddress(address)

        let hints = createHints(from: viewModelState.shouldResetRewardDestination)

        return StakingUnbondConfirmViewModel(
            senderAddress: address,
            senderIcon: icon,
            senderName: controller.name,
            collatorName: nil,
            collatorIcon: nil,
            stakeAmountViewModel: createStakedAmountViewModel(viewModelState.inputAmount),
            amountString: amount,
            hints: hints
        )
    }

    func buildBondingDurationViewModel(viewModelState _: StakingUnbondConfirmViewModelState) -> LocalizableResource<TitleWithSubtitleViewModel>? {
        nil
    }

    func createStakedAmountViewModel(
        _ amount: Decimal
    ) -> LocalizableResource<StakeAmountViewModel>? {
        let localizableBalanceFormatter = formatterFactory.createTokenFormatter(for: asset.displayInfo, usageCase: .detailsCrypto)

        let iconViewModel = asset.displayInfo.icon.map { RemoteImageViewModel(url: $0) }

        return LocalizableResource { [weak self] locale in
            let amountString = localizableBalanceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
            let stakedString = R.string.localizable.poolStakingUnstakeAmountTitle(
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
                color: self?.asset.color
            )
        }
    }
}
