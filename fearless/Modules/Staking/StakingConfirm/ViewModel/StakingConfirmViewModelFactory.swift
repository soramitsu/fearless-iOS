import Foundation
import FearlessUtils
import CommonWallet
import SoraFoundation

protocol StakingConfirmViewModelFactoryProtocol {
    func createViewModel(from state: PreparedNomination,
                         walletAccount: AccountItem) throws
    -> LocalizableResource<StakingConfirmViewModelProtocol>
}

final class StakingConfirmViewModelFactory: StakingConfirmViewModelFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()
    private lazy var amountFactory = AmountFormatterFactory()

    let asset: WalletAsset

    init(asset: WalletAsset) {
        self.asset = asset
    }

    func createViewModel(from state: PreparedNomination,
                         walletAccount: AccountItem) throws
    -> LocalizableResource<StakingConfirmViewModelProtocol> {
        let icon = try iconGenerator.generateFromAddress(walletAccount.address)

        let amountFormatter = amountFactory.createInputFormatter(for: asset)

        let rewardViewModel: RewardDestinationTypeViewModel

        switch state.rewardDestination {
        case .restake:
            rewardViewModel = .restake
        case .payout(let address):
            let payoutIcon = try iconGenerator.generateFromAddress(address)

            rewardViewModel = .payout(icon: payoutIcon, title: address)
        }

        return LocalizableResource { locale in
            let amount = amountFormatter.value(for: locale).string(from: state.amount as NSNumber)

            return StakingConfirmViewModel(senderIcon: icon,
                                           senderName: walletAccount.username,
                                           amount: amount ?? "",
                                           rewardDestination: rewardViewModel,
                                           validatorsCount: state.targets.count)
        }
    }
}
