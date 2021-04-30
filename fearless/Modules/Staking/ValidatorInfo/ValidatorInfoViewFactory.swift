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
            asset: asset,
            amountFormatterFactory: AmountFormatterFactory(),
            balanceViewModelFactory: balanceViewModelFactory
        )

        guard let assetId = WalletAssetId(rawValue: asset.identifier) else { return nil }

        let providerFactory = SingleValueProviderFactory.shared
        let priceProvider = providerFactory.getPriceProvider(for: assetId)

        let view = ValidatorInfoViewController(nib: R.nib.validatorInfoViewController)
        view.locale = localizationManager.selectedLocale

        let presenter = ValidatorInfoPresenter(
            viewModelFactory: validatorInfoViewModelFactory,
            asset: asset,
            locale: localizationManager.selectedLocale
        )

        let interactor = ValidatorInfoInteractor(
            validatorInfo: validatorInfo,
            priceProvider: priceProvider
        )
        let wireframe = ValidatorInfoWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
