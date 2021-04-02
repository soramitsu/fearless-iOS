import Foundation
import FearlessUtils
import CommonWallet
import SoraFoundation

protocol StakingConfirmViewModelFactoryProtocol {
    func createViewModel(from state: StakingConfirmationModel, asset: WalletAsset) throws
        -> LocalizableResource<StakingConfirmViewModelProtocol>
}

final class StakingConfirmViewModelFactory: StakingConfirmViewModelFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()
    private lazy var amountFactory = AmountFormatterFactory()

    func createViewModel(from state: StakingConfirmationModel, asset: WalletAsset) throws
        -> LocalizableResource<StakingConfirmViewModelProtocol> {
        let icon = try iconGenerator.generateFromAddress(state.wallet.address)

        let amountFormatter = amountFactory.createInputFormatter(for: asset)

        let rewardViewModel: RewardDestinationTypeViewModel

        switch state.rewardDestination {
        case .restake:
            rewardViewModel = .restake
        case let .payout(account):
            let payoutIcon = try iconGenerator.generateFromAddress(account.address)

            rewardViewModel = .payout(icon: payoutIcon, title: account.username)
        }

        return LocalizableResource { locale in
            let amount = amountFormatter.value(for: locale).string(from: state.amount as NSNumber)

            return StakingConfirmViewModel(
                senderIcon: icon,
                senderName: state.wallet.username,
                amount: amount ?? "",
                rewardDestination: rewardViewModel,
                validatorsCount: state.targets.count
            )
        }
    }
}
