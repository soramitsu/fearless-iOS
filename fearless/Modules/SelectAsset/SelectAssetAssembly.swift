import UIKit
import SoraFoundation
import RobinHood
import SoraUI
import SSFModels

final class SelectAssetAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        selectedAssetId: AssetModel.Id?,
        chainAssets: [ChainAsset]?,
        searchTextsViewModel: TextSearchViewModel?,
        output: SelectAssetModuleOutput,
        contextTag: Int? = nil,
        isFullSize: Bool = false,
        isEmbed: Bool = false
    ) -> SelectAssetModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let chainRepository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(),
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated

        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: operationQueue
        )

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: wallet
        )

        let interactor = SelectAssetInteractor(
            chainAssetFetching: chainAssetFetching,
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            chainAssets: chainAssets,
            wallet: wallet
        )
        let router = SelectAssetRouter()

        let viewModelFactory = SelectAssetViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )
        let presenter = SelectAssetPresenter(
            viewModelFactory: viewModelFactory,
            wallet: wallet,
            selectedAssetId: selectedAssetId,
            searchTextsViewModel: searchTextsViewModel,
            interactor: interactor,
            router: router,
            output: output,
            localizationManager: localizationManager,
            contextTag: contextTag
        )

        let view = SelectAssetViewController(
            isFullSize: isFullSize,
            output: presenter,
            localizationManager: localizationManager,
            embed: isEmbed
        )
        if !isFullSize {
            view.modalPresentationStyle = .custom

            let factory = ModalSheetBlurPresentationFactory(
                configuration: ModalSheetPresentationConfiguration.fearlessBlur
            )
            view.modalTransitioningFactory = factory
        }

        return (view, presenter)
    }
}
