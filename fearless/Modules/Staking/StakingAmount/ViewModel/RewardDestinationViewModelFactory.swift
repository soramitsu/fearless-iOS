import Foundation
import SoraFoundation
import FearlessUtils
import CommonWallet

protocol RewardDestinationViewModelFactoryProtocol {
    func createRestake(from model: CalculatedReward?, priceData: PriceData?)
        -> LocalizableResource<RewardDestinationViewModelProtocol>

    func createPayout(from model: CalculatedReward?, priceData: PriceData?, account: AccountItem) throws
        -> LocalizableResource<RewardDestinationViewModelProtocol>
}

final class RewardDestinationViewModelFactory: RewardDestinationViewModelFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    init(balanceViewModelFactory: BalanceViewModelFactoryProtocol) {
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    func createRestake(
        from model: CalculatedReward?,
        priceData: PriceData?
    ) -> LocalizableResource<RewardDestinationViewModelProtocol> {
        guard let model = model else {
            return createEmptyReturnViewModel(from: .restake)
        }

        return createViewModel(
            from: model,
            priceData: priceData,
            type: .restake
        )
    }

    func createPayout(from model: CalculatedReward?, priceData: PriceData?, account: AccountItem) throws
        -> LocalizableResource<RewardDestinationViewModelProtocol> {
        let icon = try iconGenerator.generateFromAddress(account.address)

        let type = RewardDestinationTypeViewModel.payout(icon: icon, title: account.username)

        guard let model = model else {
            return createEmptyReturnViewModel(from: type)
        }

        return createViewModel(
            from: model,
            priceData: priceData,
            type: type
        )
    }

    // MARK: Private

    func createEmptyReturnViewModel(
        from type: RewardDestinationTypeViewModel
    ) -> LocalizableResource<RewardDestinationViewModelProtocol> {
        LocalizableResource { _ in
            RewardDestinationViewModel(rewardViewModel: nil, type: type)
        }
    }

    func createViewModel(
        from model: CalculatedReward,
        priceData: PriceData?,
        type: RewardDestinationTypeViewModel
    ) -> LocalizableResource<RewardDestinationViewModelProtocol> {
        let percentageAPYFormatter = NumberFormatter.positivePercentAPY.localizableResource()
        let percentageAPRFormatter = NumberFormatter.positivePercentAPR.localizableResource()

        let localizedRestakeBalance = balanceViewModelFactory.balanceFromPrice(
            model.restakeReturn,
            priceData: priceData
        )

        let localizedPayoutBalance = balanceViewModelFactory.balanceFromPrice(
            model.payoutReturn,
            priceData: priceData
        )

        return LocalizableResource { locale in
            let restakeBalance = localizedRestakeBalance.value(for: locale)

            let restakePercentage = percentageAPYFormatter
                .value(for: locale)
                .string(from: model.restakeReturnPercentage as NSNumber)

            let payoutBalance = localizedPayoutBalance.value(for: locale)
            let payoutPercentage = percentageAPRFormatter
                .value(for: locale)
                .string(from: model.payoutReturnPercentage as NSNumber)

            let rewardViewModel = DestinationReturnViewModel(
                restakeAmount: restakeBalance.amount,
                restakePercentage: restakePercentage ?? "",
                restakePrice: restakeBalance.price ?? "",
                payoutAmount: payoutBalance.amount,
                payoutPercentage: payoutPercentage ?? "",
                payoutPrice: payoutBalance.price ?? ""
            )

            return RewardDestinationViewModel(
                rewardViewModel: rewardViewModel,
                type: type
            )
        }
    }
}
