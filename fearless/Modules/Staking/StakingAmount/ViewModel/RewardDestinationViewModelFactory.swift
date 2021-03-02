import Foundation
import SoraFoundation
import FearlessUtils
import CommonWallet

protocol RewardDestinationViewModelFactoryProtocol {
    func createRestake(from model: CalculatedReward)
    -> LocalizableResource<RewardDestinationViewModelProtocol>

    func createPayout(from model: CalculatedReward, account: AccountItem) throws
    -> LocalizableResource<RewardDestinationViewModelProtocol>
}

final class RewardDestinationViewModelFactory: RewardDestinationViewModelFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()
    private lazy var tokenFormatter = AmountFormatterFactory()

    let asset: WalletAsset

    init(asset: WalletAsset) {
        self.asset = asset
    }

    func createRestake(from model: CalculatedReward)
    -> LocalizableResource<RewardDestinationViewModelProtocol> {
        let amountFormatter = tokenFormatter.createTokenFormatter(for: asset)

        return createViewModel(from: model,
                               amountFormatter: amountFormatter,
                               type: .restake)
    }

    func createPayout(from model: CalculatedReward, account: AccountItem) throws
    -> LocalizableResource<RewardDestinationViewModelProtocol> {
        let icon = try iconGenerator.generateFromAddress(account.address)

        let amountFormatter = tokenFormatter.createTokenFormatter(for: asset)
        return createViewModel(from: model,
                               amountFormatter: amountFormatter,
                               type: .payout(icon: icon, title: account.username))
    }

    // MARK: Private

    func createViewModel(from model: CalculatedReward,
                         amountFormatter: LocalizableResource<TokenAmountFormatter>,
                         type: RewardDestinationTypeViewModel)
    -> LocalizableResource<RewardDestinationViewModelProtocol> {
        LocalizableResource { locale in
            let amountFormatter = amountFormatter.value(for: locale)
            let percentageFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

            let restakeAmount = amountFormatter.string(from: model.restakeReturn)
            let restakePercentage = percentageFormatter.string(from: model.restakeReturnPercentage as NSNumber)

            let payoutAmount = amountFormatter.string(from: model.payoutReturn)
            let payoutPercentage = percentageFormatter
                .string(from: model.payoutReturnPercentage as NSNumber)

            return RewardDestinationViewModel(restakeAmount: restakeAmount ?? "",
                                              restakePercentage: restakePercentage ?? "",
                                              payoutAmount: payoutAmount ?? "",
                                              payoutPercentage: payoutPercentage ?? "",
                                              type: type)
        }
    }
}
