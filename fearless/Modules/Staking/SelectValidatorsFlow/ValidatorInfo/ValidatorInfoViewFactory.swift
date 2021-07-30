import Foundation
import FearlessUtils
import SoraKeystore
import SoraFoundation

final class ValidatorInfoViewFactory {
    private static func createView(
        with interactor: ValidatorInfoInteractorBase
    ) -> ValidatorInfoViewProtocol? {
        let localizationManager = LocalizationManager.shared
        let settings = SettingsManager.shared

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: settings.selectedConnection.type,
            limit: StakingConstants.maxAmount
        )

        let validatorInfoViewModelFactory = ValidatorInfoViewModelFactory(
            iconGenerator: PolkadotIconGenerator(),
            balanceViewModelFactory: balanceViewModelFactory
        )

        let wireframe = ValidatorInfoWireframe()

        let presenter = ValidatorInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: validatorInfoViewModelFactory,
            chain: settings.selectedConnection.type.chain,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ValidatorInfoViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createAssetId() -> WalletAssetId? {
        let settings = SettingsManager.shared
        let networkType = settings.selectedConnection.type

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(networkType)

        return WalletAssetId(rawValue: asset.identifier)
    }
}

extension ValidatorInfoViewFactory: ValidatorInfoViewFactoryProtocol {
    static func createView(with validatorInfo: ValidatorInfoProtocol) -> ValidatorInfoViewProtocol? {
        guard let assetId = createAssetId() else { return nil }

        let providerFactory = SingleValueProviderFactory.shared

        let interactor = AnyValidatorInfoInteractor(
            validatorInfo: validatorInfo,
            singleValueProviderFactory: providerFactory,
            walletAssetId: assetId
        )

        return createView(with: interactor)
    }

    static func createView(with accountAddress: AccountAddress) -> ValidatorInfoViewProtocol? {
        guard let engine = WebSocketService.shared.connection,
              let assetId = createAssetId()
        else { return nil }

        let settings = SettingsManager.shared

        let chain = settings.selectedConnection.type.chain

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let validatorOperationFactory = ValidatorOperationFactory(
            chain: chain,
            eraValidatorService: EraValidatorFacade.sharedService,
            rewardService: RewardCalculatorFacade.sharedService,
            storageRequestFactory: storageRequestFactory,
            runtimeService: RuntimeRegistryFacade.sharedService,
            engine: engine,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory)
        )

        let providerFactory = SingleValueProviderFactory.shared

        let interactor = YourValidatorInfoInteractor(
            accountAddress: accountAddress,
            singleValueProviderFactory: providerFactory,
            walletAssetId: assetId,
            validatorOperationFactory: validatorOperationFactory,
            operationManager: OperationManagerFacade.sharedManager
        )

        return createView(with: interactor)
    }
}
