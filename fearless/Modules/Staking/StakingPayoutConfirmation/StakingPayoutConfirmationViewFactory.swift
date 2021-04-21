import Foundation
import SoraFoundation
import SoraKeystore
import FearlessUtils

final class StakingPayoutConfirmationViewFactory: StakingPayoutConfirmationViewFactoryProtocol {
    static func createView(payouts: [PayoutInfo]) -> StakingPayoutConfirmationViewProtocol? {
        guard let connection = WebSocketService.shared.connection else {
            return nil
        }

        let settings = SettingsManager.shared
        let keystore = Keychain()

        let networkType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(settings.selectedConnection.type)
        let chain = settings.selectedConnection.type.chain

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: networkType,
            limit: StakingConstants.maxAmount
        )

        let payoutConfirmViewModelFactory = StakingPayoutConfirmViewModelFactory(
            asset: asset,
            balanceViewModelFactory: balanceViewModelFactory
        )

        let presenter = StakingPayoutConfirmationPresenter(
            balanceViewModelFactory: balanceViewModelFactory,
            payoutConfirmViewModelFactory: payoutConfirmViewModelFactory,
            chain: chain,
            asset: asset,
            logger: Logger.shared
        )

        let view = StakingPayoutConfirmationViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        guard let interactor = createInteractor(
            connection: connection,
            settings: settings,
            keystore: keystore,
            payouts: payouts
        ) else {
            return nil
        }

        let wireframe = StakingPayoutConfirmationWireframe()

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        connection: JSONRPCEngine,
        settings: SettingsManagerProtocol,
        keystore: KeystoreProtocol,
        payouts: [PayoutInfo]
    ) -> StakingPayoutConfirmationInteractor? {
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)

        let runtimeService = RuntimeRegistryFacade.sharedService

        let asset = primitiveFactory.createAssetForAddressType(settings.selectedConnection.type)

        guard let selectedAccount = settings.selectedAccount,
              let assetId = WalletAssetId(rawValue: asset.identifier)
        else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let extrinsicService = ExtrinsicService(
            address: selectedAccount.address,
            cryptoType: selectedAccount.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let signer = SigningWrapper(
            keystore: keystore,
            settings: settings
        )

        let providerFactory = SingleValueProviderFactory.shared

        guard let balanceProvider = try? providerFactory
            .getAccountProvider(
                for: selectedAccount.address,
                runtimeService: runtimeService
            )
        else {
            return nil
        }

        let substrateProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        let priceProvider = providerFactory.getPriceProvider(for: assetId)

        return StakingPayoutConfirmationInteractor(
            providerFactory: providerFactory,
            substrateProviderFactory: substrateProviderFactory,
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            signer: signer,
            balanceProvider: balanceProvider,
            priceProvider: priceProvider,
            settings: settings,
            logger: Logger.shared,
            payouts: payouts
        )
    }
}
