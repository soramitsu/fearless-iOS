import Foundation
import SoraFoundation
import FearlessUtils
import CommonWallet

protocol RewardDestinationViewModelFactoryProtocol {
    func createRestake(from model: CalculatedReward?)
    -> LocalizableResource<RewardDestinationViewModelProtocol>

    func createPayout(from model: CalculatedReward?, account: AccountItem) throws
    -> LocalizableResource<RewardDestinationViewModelProtocol>
}

final class RewardDestinationViewModelFactory: RewardDestinationViewModelFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()
    private lazy var tokenFormatter = AmountFormatterFactory()

    let asset: WalletAsset

    init(asset: WalletAsset) {
        self.asset = asset
    }

    func createRestake(from model: CalculatedReward?)
    -> LocalizableResource<RewardDestinationViewModelProtocol> {
        guard let model = model else {
            return createEmptyReturnViewModel(from: .restake)
        }

        let amountFormatter = tokenFormatter.createTokenFormatter(for: asset)

        return createViewModel(from: model,
                               amountFormatter: amountFormatter,
                               type: .restake)
    }

    func createPayout(from model: CalculatedReward?, account: AccountItem) throws
    -> LocalizableResource<RewardDestinationViewModelProtocol> {
        let icon = try iconGenerator.generateFromAddress(account.address)

        let type = RewardDestinationTypeViewModel.payout(icon: icon, title: account.username)

        guard let model = model else {
            return createEmptyReturnViewModel(from: type)
        }

        let amountFormatter = tokenFormatter.createTokenFormatter(for: asset)
        return createViewModel(from: model,
                               amountFormatter: amountFormatter,
                               type: type)
    }

    // MARK: Private

    func createEmptyReturnViewModel(from type: RewardDestinationTypeViewModel)
    -> LocalizableResource<RewardDestinationViewModelProtocol> {
        LocalizableResource { _ in
            RewardDestinationViewModel(rewardViewModel: nil, type: type)
        }
    }

    func createViewModel(from model: CalculatedReward,
                         amountFormatter: LocalizableResource<TokenAmountFormatter>,
                         type: RewardDestinationTypeViewModel)
    -> LocalizableResource<RewardDestinationViewModelProtocol> {
        LocalizableResource { locale in
            let amountFormatter = amountFormatter.value(for: locale)
            let percentageFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

            let restakeAmount = model.restakeReturn > 0.0 ?
                amountFormatter.string(from: model.restakeReturn) : nil
            let restakePercentage = percentageFormatter.string(from: model.restakeReturnPercentage as NSNumber)

            let payoutAmount = model.payoutReturn > 0.0 ?
                amountFormatter.string(from: model.payoutReturn) : nil
            let payoutPercentage = percentageFormatter
                .string(from: model.payoutReturnPercentage as NSNumber)

            let rewardViewModel = DestinationReturnViewModel(restakeAmount: restakeAmount ?? "",
                                                             restakePercentage: restakePercentage ?? "",
                                                             payoutAmount: payoutAmount ?? "",
                                                             payoutPercentage: payoutPercentage ?? "")

            return RewardDestinationViewModel(rewardViewModel: rewardViewModel,
                                              type: type)
        }
    }
}
