import Foundation
import FearlessUtils
import SoraKeystore
import SoraFoundation

final class ValidatorInfoViewFactory: ValidatorInfoViewFactoryProtocol {
    static func createView(with validatorInfo: ValidatorInfoProtocol) -> ValidatorInfoViewProtocol? {
        let localizationManager = LocalizationManager.shared
        let settings = SettingsManager.shared
        let networkType = settings.selectedConnection.type

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(networkType)

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: settings.selectedConnection.type,
            limit: StakingConstants.maxAmount
        )

        let validatorInfoViewModelFactory = ValidatorInfoViewModelFactory(
            iconGenerator: PolkadotIconGenerator(),
            balanceViewModelFactory: balanceViewModelFactory
        )

        guard let assetId = WalletAssetId(rawValue: asset.identifier) else { return nil }

        let providerFactory = SingleValueProviderFactory.shared
        let priceProvider = providerFactory.getPriceProvider(for: assetId)

        let interactor = ValidatorInfoInteractor(
            validatorInfo: validatorInfo,
            priceProvider: priceProvider
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
}
