import Foundation
import SoraKeystore
import SoraFoundation
import RobinHood

final class StakingConfirmViewFactory: StakingConfirmViewFactoryProtocol {
    static func createInitiatedBondingView(for state: PreparedNomination<InitiatedBonding>)
    -> StakingConfirmViewProtocol? {
        let settings = SettingsManager.shared
        let keystore = Keychain()

        guard let connection = WebSocketService.shared.connection else {
            return nil
        }

        guard let interactor = createInitiatedBondingInteractor(state,
                                                                connection: connection,
                                                                settings: settings,
                                                                keystore: keystore) else {
            return nil
        }

        guard let presenter = createPresenter(settings: settings,
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

    static func createChangeTargetsView(for state: PreparedNomination<ExistingBonding>)
    -> StakingConfirmViewProtocol? {
        return nil
    }

    static private func createPresenter(settings: SettingsManagerProtocol,
                                        keystore: KeystoreProtocol) -> StakingConfirmPresenter? {
        let networkType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(keystore: keystore, settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(settings.selectedConnection.type)

        let confirmViewModelFactory = StakingConfirmViewModelFactory()

        let balanceViewModelFactory = BalanceViewModelFactory(walletPrimitiveFactory: primitiveFactory,
                                                              selectedAddressType: networkType,
                                                              limit: StakingConstants.maxAmount)

        return StakingConfirmPresenter(confirmationViewModelFactory: confirmViewModelFactory,
                                       balanceViewModelFactory: balanceViewModelFactory,
                                       asset: asset)
    }

    static private func createInitiatedBondingInteractor(_ nomation: PreparedNomination<InitiatedBonding>,
                                                         connection: JSONRPCEngine,
                                                         settings: SettingsManagerProtocol,
                                                         keystore: KeystoreProtocol)
    -> InitiatedBondingConfirmInteractor? {
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

        return InitiatedBondingConfirmInteractor(priceProvider: AnySingleValueProvider(priceProvider),
                                                 balanceProvider: AnyDataProvider(balanceProvider),
                                                 extrinsicService: extrinsicService,
                                                 operationManager: operationManager,
                                                 signer: signer,
                                                 settings: settings,
                                                 nomination: nomation)
    }
}
