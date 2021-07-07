import Foundation
import SoraFoundation
import RobinHood
import SoraKeystore

struct SignerConfirmViewFactory {
    static func createView(from request: SignerOperationRequestProtocol) -> SignerConfirmViewProtocol? {
        let settings = SettingsManager.shared

        guard let selectedAccount = settings.selectedAccount, let connection = WebSocketService.shared.engine else {
            return nil
        }

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let networkType = settings.selectedConnection.type
        let asset = primitiveFactory.createAssetForAddressType(networkType)

        guard let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return nil
        }

        let runtimeService = RuntimeRegistryFacade.sharedService
        let operationManager = OperationManagerFacade.sharedManager
        let signer = SigningWrapper(keystore: Keychain(), settings: settings)

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        ).createService(accountItem: selectedAccount)

        let interactor = SignerConfirmInteractor(
            selectedAccount: selectedAccount,
            assetId: assetId,
            request: request,
            runtimeService: runtimeService,
            extrinsicService: extrinsicService,
            signer: signer,
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            operationManager: operationManager
        )

        let wireframe = SignerConfirmWireframe()

        let dataValidating = TransferDataValidatorFactory(presentable: wireframe)
        let localizationManager = LocalizationManager.shared

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: networkType,
            limit: Decimal.greatestFiniteMagnitude
        )

        let viewModelFactory = SignerConfirmViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            chain: networkType.chain
        )

        let presenter = SignerConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chain: networkType.chain,
            selectedAccount: selectedAccount,
            dataValidatingFactory: dataValidating,
            localizationManager: localizationManager
        )

        let view = SignerConfirmViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.view = view
        dataValidating.view = view
        interactor.presenter = presenter

        return view
    }
}
