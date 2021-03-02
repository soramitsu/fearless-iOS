import Foundation
import SoraKeystore
import SoraFoundation
import RobinHood

final class StakingConfirmViewFactory: StakingConfirmViewFactoryProtocol {
    static func createView(for state: PreparedNomination) -> StakingConfirmViewProtocol? {
        let settings = SettingsManager.shared
        let keystore = Keychain()

        guard let connection = WebSocketService.shared.connection else {
            return nil
        }

        guard let interactor = createInteractor(connection: connection,
                                                settings: settings,
                                                keystore: keystore) else {
            return nil
        }

        guard let presenter = createPresenter(state: state,
                                              settings: settings,
                                              keystore: keystore) else {
            return nil
        }

        let view = StakingConfirmViewController(nib: R.nib.stakingConfirmViewController)
        view.uiFactory = UIFactory()

        let wireframe = StakingConfirmWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }

    static private func createPresenter(state: PreparedNomination,
                                        settings: SettingsManagerProtocol,
                                        keystore: KeystoreProtocol) -> StakingConfirmPresenter? {
        let networkType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(keystore: keystore, settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(settings.selectedConnection.type)

        guard let selectedAccount = settings.selectedAccount else {
            return nil
        }

        let confirmViewModelFactory = StakingConfirmViewModelFactory(asset: asset)

        let balanceViewModelFactory = BalanceViewModelFactory(walletPrimitiveFactory: primitiveFactory,
                                                              selectedAddressType: networkType)

        return StakingConfirmPresenter(state: state,
                                       asset: asset,
                                       walletAccount: selectedAccount,
                                       confirmationViewModelFactory: confirmViewModelFactory,
                                       balanceViewModelFactory: balanceViewModelFactory,
                                       logger: Logger.shared)
    }

    static private func createInteractor(connection: JSONRPCEngine,
                                         settings: SettingsManagerProtocol,
                                         keystore: KeystoreProtocol) -> StakingConfirmInteractor? {
        let primitiveFactory = WalletPrimitiveFactory(keystore: keystore, settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(settings.selectedConnection.type)

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

        let operationManager = OperationManagerFacade.sharedManager

        let extrinsicService = ExtrinsicService(address: selectedAccount.address,
                                                cryptoType: selectedAccount.cryptoType,
                                                runtimeRegistry: RuntimeRegistryFacade.sharedService,
                                                engine: connection,
                                                operationManager: operationManager)

        let signer = SigningWrapper(keystore: keystore,
                                    settings: settings)

        let priceProvider = providerFactory.getPriceProvider(for: assetId)

        return StakingConfirmInteractor(priceProvider: AnySingleValueProvider(priceProvider),
                                        balanceProvider: AnyDataProvider(balanceProvider),
                                        extrinsicService: extrinsicService,
                                        operationManager: operationManager,
                                        signer: signer)
    }
}
