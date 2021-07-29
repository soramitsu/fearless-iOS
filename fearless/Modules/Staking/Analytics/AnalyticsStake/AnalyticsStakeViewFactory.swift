import Foundation
import SoraKeystore

struct AnalyticsStakeViewFactory {
    static func createView() -> AnalyticsStakeViewProtocol? {
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
            let subqueryUrl = assetId.subqueryUrl // URL(string: "http://localhost:3000/")
        else {
            return nil
        }

        let subqueryStakeSource = SubqueryStakeSource(address: accountAddress, url: subqueryUrl)
        let interactor = AnalyticsStakeInteractor(
            subqueryStakeSource: subqueryStakeSource,
            operationManager: operationManager
        )
        let wireframe = AnalyticsStakeWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: addressType,
            limit: StakingConstants.maxAmount
        )
        let viewModelFactory = AnalyticsStakeViewModelFactory(
            chain: chain,
            balanceViewModelFactory: balanceViewModelFactory
        )
        let presenter = AnalyticsStakePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory
        )

        let view = AnalyticsStakeViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
