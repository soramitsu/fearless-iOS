import Foundation
import SoraFoundation
import SoraKeystore
import SSFUtils
import SSFModels

final class StakingRewardDetailsViewFactory: StakingRewardDetailsViewFactoryProtocol {
    static func createView(
        selectedAccount: MetaAccountModel,
        chain: ChainModel,
        asset: AssetModel,
        input: StakingRewardDetailsInput
    ) -> StakingRewardDetailsViewProtocol? {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,

            selectedMetaAccount: selectedAccount
        )

        let viewModelFactory = StakingRewardDetailsViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            iconGenerator: UniversalIconGenerator(chain: chain)
        )

        let presenter = StakingRewardDetailsPresenter(
            asset: asset,
            selectedAccount: selectedAccount,
            chain: chain,
            input: input,
            viewModelFactory: viewModelFactory
        )
        let view = StakingRewardDetailsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)

        let interactor = StakingRewardDetailsInteractor(
            asset: asset,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory
        )
        let wireframe = StakingRewardDetailsWireframe()

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
