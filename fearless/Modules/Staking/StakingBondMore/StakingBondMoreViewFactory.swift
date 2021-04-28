import SoraFoundation
import SoraKeystore
import RobinHood
import FearlessUtils

struct StakingBondMoreViewFactory {
    static func createView() -> StakingBondMoreViewProtocol? {
        let interactor = StakingBondMoreInteractor()
        let wireframe = StakingBondMoreWireframe()
        // let viewModelFactory = StakingBondMoreViewModelFactory()

        let settings = SettingsManager.shared
        let networkType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(networkType)

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: networkType,
            limit: StakingConstants.maxAmount
        )

        let presenter = StakingBondMorePresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory
        )
        let viewController = StakingBondMoreViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = viewController
        interactor.presenter = presenter

        return viewController
    }
}
