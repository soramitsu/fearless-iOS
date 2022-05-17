import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

protocol StakingUnbondConfirmViewModelFactoryProtocol {
    func createUnbondConfirmViewModel(
        controllerItem: ChainAccountResponse,
        amount: Decimal,
        shouldResetRewardDestination: Bool
    ) throws -> StakingUnbondConfirmViewModel
}

final class StakingUnbondConfirmViewModelFactory: StakingUnbondConfirmViewModelFactoryProtocol {
    let asset: AssetModel

    private lazy var formatterFactory = AssetBalanceFormatterFactory()
    private lazy var iconGenerator = PolkadotIconGenerator()

    init(asset: AssetModel) {
        self.asset = asset
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

    func createUnbondConfirmViewModel(
        controllerItem: ChainAccountResponse,
        amount: Decimal,
        shouldResetRewardDestination: Bool
    ) throws -> StakingUnbondConfirmViewModel {
        let formatter = formatterFactory.createInputFormatter(for: asset.displayInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: amount as NSNumber) ?? ""
        }

        let address = controllerItem.toAddress() ?? ""
        let icon = try iconGenerator.generateFromAddress(address)

        let hints = createHints(from: shouldResetRewardDestination)

        return StakingUnbondConfirmViewModel(
            senderAddress: address,
            senderIcon: icon,
            senderName: controllerItem.name,
            amount: amount,
            hints: hints
        )
    }
}
