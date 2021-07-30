import Foundation
import SoraKeystore

struct AnalyticsRewardsViewFactory {
    static func createView() -> AnalyticsRewardsViewProtocol? {
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

        let interactor = AnalyticsRewardsInteractor(
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            analyticsService: analyticsService,
            assetId: assetId
        )
        let wireframe = AnalyticsRewardsWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: addressType,
            limit: StakingConstants.maxAmount
        )

        let viewModelFactory = AnalyticsRewardsViewModelFactory(chain: chain, balanceViewModelFactory: balanceViewModelFactory)
        let presenter = AnalyticsRewardsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory
        )

        let view = AnalyticsRewardsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
