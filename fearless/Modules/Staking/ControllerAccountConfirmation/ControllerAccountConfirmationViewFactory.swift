import Foundation
import SoraFoundation
import FearlessUtils
import SoraKeystore

struct ControllerAccountConfirmationViewFactory {
    static func createView(
        stashAccountItem: AccountItem,
        controllerAccountItem: AccountItem
    ) -> ControllerAccountConfirmationViewProtocol? {
        let settings = SettingsManager.shared

        guard let engine = WebSocketService.shared.connection else {
            return nil
        }

        let chain = settings.selectedConnection.type.chain
        let networkType = chain.addressType

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)

        let asset = primitiveFactory.createAssetForAddressType(networkType)

        guard let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return nil
        }

        let extrinsicService = ExtrinsicService(
            address: stashAccountItem.address,
            cryptoType: stashAccountItem.cryptoType,
            runtimeRegistry: RuntimeRegistryFacade.sharedService,
            engine: engine,
            operationManager: OperationManagerFacade.sharedManager
        )

        let interactor = ControllerAccountConfirmationInteractor(
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            extrinsicService: extrinsicService,
            signingWrapper: SigningWrapper(keystore: Keychain(), settings: settings),
            feeProxy: ExtrinsicFeeProxy(),
            assetId: assetId,
            stashAccountItem: stashAccountItem
        )

        let wireframe = ControllerAccountConfirmationWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let presenter = ControllerAccountConfirmationPresenter(
            stashAccountItem: stashAccountItem,
            controllerAccountItem: controllerAccountItem,
            chain: chain,
            iconGenerator: PolkadotIconGenerator(),
            balanceViewModelFactory: balanceViewModelFactory
        )

        let view = ControllerAccountConfirmationVC(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
