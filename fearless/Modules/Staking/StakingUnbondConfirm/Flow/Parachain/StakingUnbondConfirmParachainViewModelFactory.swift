import Foundation
import FearlessUtils
import SoraFoundation

final class StakingUnbondConfirmParachainViewModelFactory: StakingUnbondConfirmViewModelFactoryProtocol {
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
        guard let viewModelState = viewModelState as? StakingUnbondConfirmParachainViewModelState else {
            return nil
        }

        let formatter = formatterFactory.createInputFormatter(for: asset.displayInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: viewModelState.inputAmount as NSNumber) ?? ""
        }

        let address = viewModelState.accountAddress ?? ""
        let icon = try? iconGenerator.generateFromAddress(address)

        let hints = createHints(from: false)

        return StakingUnbondConfirmViewModel(
            senderAddress: address,
            senderIcon: icon,
            senderName: viewModelState.wallet.fetch(for: viewModelState.chainAsset.chain.accountRequest())?.name,
            amount: amount,
            hints: hints
        )
    }
}
