import Foundation
import SoraFoundation
import SoraKeystore

final class StakingRewardDetailsViewFactory: StakingRewardDetailsViewFactoryProtocol {
    static func createView(payoutItem: StakingPayoutItem, chain: Chain) -> StakingRewardDetailsViewProtocol? {
        let settings = SettingsManager.shared
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let presenter = StakingRewardDetailsPresenter(
            chain: chain,
            balanceViewModelFactory: balanceViewModelFactory
        )
        let view = StakingRewardDetailsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        let interactor = StakingRewardDetailsInteractor(payoutItem: payoutItem)
        let wireframe = StakingRewardDetailsWireframe()

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
