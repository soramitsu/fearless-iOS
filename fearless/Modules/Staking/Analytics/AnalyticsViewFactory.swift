import Foundation
import SoraKeystore

struct AnalyticsViewFactory {
    static func createView() -> AnalyticsViewProtocol? {
        let settings = SettingsManager.shared
        let operationManager = OperationManagerFacade.sharedManager

        let networkType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(networkType)
        let addressType = settings.selectedConnection.type
        let chain = addressType.chain
        guard
            let accountAddress = settings.selectedAccount?.address,
            let assetId = WalletAssetId(rawValue: asset.identifier),
            let subqueryUrl = assetId.subqueryUrl
        else {
            return nil
        }

        let analyticsService = AnalyticsService(
            url: subqueryUrl,
            address: accountAddress,
            operationManager: operationManager
        )

        let interactor = AnalyticsInteractor(
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            analyticsService: analyticsService,
            assetId: assetId
        )
        let wireframe = AnalyticsWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: addressType,
            limit: StakingConstants.maxAmount
        )

        let viewModelFactory = AnalyticsViewModelFactory(chain: chain, balanceViewModelFactory: balanceViewModelFactory)
        let presenter = AnalyticsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory
        )

        let stakeModule = AnalyticsStakeViewFactory.createView()
        let view = AnalyticsViewController(presenter: presenter, stakeView: stakeModule)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
