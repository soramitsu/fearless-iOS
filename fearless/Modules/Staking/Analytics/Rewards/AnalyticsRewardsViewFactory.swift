import Foundation
import SoraKeystore
import SoraFoundation

struct AnalyticsRewardsViewFactory {
    static func createView() -> AnalyticsRewardsViewProtocol? {
        let settings = SettingsManager.shared

        let networkType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(networkType)
        let addressType = settings.selectedConnection.type
        let chain = addressType.chain
        guard
            let accountAddress = settings.selectedAccount?.address,
            let assetId = WalletAssetId(rawValue: asset.identifier)
        else {
            return nil
        }

        let interactor = createInteractor(accountAddress: accountAddress, chain: chain, assetId: assetId)
        let wireframe = AnalyticsRewardsWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: addressType,
            limit: StakingConstants.maxAmount
        )

        let viewModelFactory = AnalyticsRewardsViewModelFactory(
            chain: chain,
            balanceViewModelFactory: balanceViewModelFactory,
            calendar: Calendar(identifier: .gregorian)
        )

        let presenter = AnalyticsRewardsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = AnalyticsRewardsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        accountAddress: AccountAddress,
        chain: Chain,
        assetId: WalletAssetId
    ) -> AnalyticsRewardsInteractor {
        let operationManager = OperationManagerFacade.sharedManager

        let substrateProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateDataStorageFacade.shared,
            operationManager: operationManager
        )

        let interactor = AnalyticsRewardsInteractor(
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            substrateProviderFactory: substrateProviderFactory,
            operationManager: operationManager,
            assetId: assetId,
            chain: chain,
            selectedAccountAddress: accountAddress
        )
        return interactor
    }
}
