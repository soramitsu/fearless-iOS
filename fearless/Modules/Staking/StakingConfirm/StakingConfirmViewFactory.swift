import Foundation
import SoraKeystore
import SoraFoundation

final class StakingConfirmViewFactory: StakingConfirmViewFactoryProtocol {
    static func createView(for state: PreparedNomination) -> StakingConfirmViewProtocol? {
        let settings = SettingsManager.shared
        let keystore = Keychain()
        let logger = Logger.shared

        let networkType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(keystore: keystore, settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(networkType)

        guard let selectedAccount = settings.selectedAccount,
              let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return nil
        }

        let providerFactory = SingleValueProviderFactory.shared
        guard let balanceProvider = try? providerFactory
                .getAccountProvider(for: selectedAccount.address,
                                    runtimeService: RuntimeRegistryFacade.sharedService) else {
            return nil
        }

        guard let connection = WebSocketService.shared.connection else {
            return nil
        }

        let view = StakingConfirmViewController(nib: R.nib.stakingConfirmViewController)
        view.uiFactory = UIFactory()

        let confirmViewModelFactory = StakingConfirmViewModelFactory(asset: asset)

        let balanceViewModelFactory = BalanceViewModelFactory(walletPrimitiveFactory: primitiveFactory,
                                                              selectedAddressType: networkType)

        let presenter = StakingConfirmPresenter(state: state,
                                                asset: asset,
                                                walletAccount: selectedAccount,
                                                confirmationViewModelFactory: confirmViewModelFactory,
                                                balanceViewModelFactory: balanceViewModelFactory,
                                                logger: logger)

        let priceProvider = providerFactory.getPriceProvider(for: assetId)

        let operationManager = OperationManagerFacade.sharedManager

        let extrinsicService = ExtrinsicService(address: selectedAccount.address,
                                                cryptoType: selectedAccount.cryptoType,
                                                runtimeRegistry: RuntimeRegistryFacade.sharedService,
                                                engine: connection,
                                                operationManager: operationManager)

        let signer = SigningWrapper(keystore: keystore,
                                    settings: settings)

        let interactor = StakingConfirmInteractor(priceProvider: priceProvider,
                                                  balanceProvider: balanceProvider,
                                                  extrinsicService: extrinsicService,
                                                  operationManager: operationManager,
                                                  signer: signer)
        let wireframe = StakingConfirmWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
