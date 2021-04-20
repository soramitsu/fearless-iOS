import Foundation
import SoraKeystore
import SoraFoundation
import FearlessUtils

final class StakingRewardPayoutsViewFactory: StakingRewardPayoutsViewFactoryProtocol {
    static func createView() -> StakingRewardPayoutsViewProtocol? {
        let settings = SettingsManager.shared
        let connection = settings.selectedConnection
        let operationManager = OperationManagerFacade.sharedManager

        guard let selectedAccount = settings.selectedAccount else { return nil }

        let chain = connection.type.chain

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)

        let asset = primitiveFactory.createAssetForAddressType(chain.addressType)

        guard let assetId = WalletAssetId(rawValue: asset.identifier),
              let subscanUrl = assetId.subscanUrl else {
            return nil
        }

        guard let engine = WebSocketService.shared.connection else { return nil }

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: connection.type,
            limit: StakingConstants.maxAmount
        )
        let presenter = StakingRewardPayoutsPresenter(
            chain: chain,
            balanceViewModelFactory: balanceViewModelFactory
        )
        let view = StakingRewardPayoutsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        let storageRequestFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory())

        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageRequestFactory)

        let payoutService = PayoutRewardsService(
            selectedAccountAddress: selectedAccount.address,
            chain: chain,
            subscanBaseURL: subscanUrl,
            runtimeCodingService: RuntimeRegistryFacade.sharedService,
            storageRequestFactory: storageRequestFactory,
            engine: engine,
            operationManager: operationManager,
            subscanOperationFactory: SubscanOperationFactory(),
            identityOperationFactory: identityOperationFactory,
            logger: Logger.shared
        )

        let providerFactory = SingleValueProviderFactory.shared
        let priceProvider = providerFactory.getPriceProvider(for: assetId)

        let interactor = StakingRewardPayoutsInteractor(
            payoutService: payoutService,
            priceProvider: priceProvider,
            operationManager: operationManager
        )
        let wireframe = StakingRewardPayoutsWireframe()

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
