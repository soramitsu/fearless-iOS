import Foundation
import SoraFoundation
import SoraKeystore
import FearlessUtils

final class StakingRewardDetailsViewFactory: StakingRewardDetailsViewFactoryProtocol {
    static func createView(input: StakingRewardDetailsInput) -> StakingRewardDetailsViewProtocol? {
        let settings = SettingsManager.shared
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: input.chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let viewModelFactory = StakingRewardDetailsViewModelFactory(
            input: input,
            balanceViewModelFactory: balanceViewModelFactory,
            iconGenerator: PolkadotIconGenerator()
        )
        let presenter = StakingRewardDetailsPresenter(
            payoutInfo: input.payoutInfo,
            chain: input.chain,
            viewModelFactory: viewModelFactory
        )
        let view = StakingRewardDetailsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        let asset = primitiveFactory.createAssetForAddressType(input.chain.addressType)

        guard let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return nil
        }
        let providerFactory = SingleValueProviderFactory.shared
        let priceProvider = providerFactory.getPriceProvider(for: assetId)
        let interactor = StakingRewardDetailsInteractor(priceProvider: priceProvider)
        let wireframe = StakingRewardDetailsWireframe()

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
