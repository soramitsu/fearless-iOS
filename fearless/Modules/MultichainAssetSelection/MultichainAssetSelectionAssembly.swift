import UIKit
import SoraFoundation

final class MultichainAssetSelectionAssembly {
    static func configureModule(flow: MultichainChainFetchingFlow, wallet: MetaAccountModel, selectAssetModuleOutput: SelectAssetModuleOutput?) -> MultichainAssetSelectionModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = MultichainAssetSelectionInteractor(
            chainFetching: buildChainFetching(flow: flow),
            assetFetching: buildAssetFetching(flow: flow)
        )
        let router = MultichainAssetSelectionRouter()

        let presenter = MultichainAssetSelectionPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: MultichainAssetSelectionViewModelFactoryImpl(),
            logger: Logger.shared,
            selectAssetModuleOutput: selectAssetModuleOutput
        )
        guard let selectAssetModule = createSelectAssetModule(wallet: wallet, moduleOutput: presenter) else {
            return nil
        }

        presenter.selectAssetModuleInput = selectAssetModule.input

        let view = MultichainAssetSelectionViewController(
            output: presenter,
            localizationManager: localizationManager,
            selectAssetViewController: selectAssetModule.view.controller
        )

        return (view, presenter)
    }

    private static func buildChainFetching(flow _: MultichainChainFetchingFlow) -> MultichainChainFetching {
        let chainsRepository = ChainRepositoryFactory().createAsyncRepository()
        return OKXMultichainChainFetching(chainsRepository: chainsRepository)
    }

    private static func buildAssetFetching(flow _: MultichainChainFetchingFlow) -> MultichainAssetFetching {
        OKXMultichainAssetFetching()
    }

    private static func createSelectAssetModule(wallet: MetaAccountModel, moduleOutput: SelectAssetModuleOutput) -> SelectAssetModuleCreationResult? {
        SelectAssetAssembly.configureModule(wallet: wallet, selectedAssetId: nil, chainAssets: nil, searchTextsViewModel: .searchAssetPlaceholder, output: moduleOutput, isEmbed: true)
    }
}
