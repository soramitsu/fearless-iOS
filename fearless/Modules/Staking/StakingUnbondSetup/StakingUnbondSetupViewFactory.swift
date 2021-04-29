import Foundation
import SoraFoundation
import SoraKeystore

final class StakingUnbondSetupViewFactory: StakingUnbondSetupViewFactoryProtocol {
    static func createView() -> StakingUnbondSetupViewProtocol? {
        let interactor = StakingUnbondSetupInteractor()
        let wireframe = StakingUnbondSetupWireframe()

        let settings = SettingsManager.shared
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let chain = settings.selectedConnection.type.chain

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let presenter = StakingUnbondSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory
        )

        let view = StakingUnbondSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
