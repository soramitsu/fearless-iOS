import UIKit
import SoraFoundation
import SSFNetwork
import SSFModels

final class MultichainAssetSelectionAssembly {
    static func configureModule(
        flow: MultichainChainFetchingFlow,
        wallet: MetaAccountModel,
        selectAssetModuleOutput: SelectAssetModuleOutput?,
        contextTag: Int? = nil,
        selectedChainAsset: ChainAsset?
    ) -> MultichainAssetSelectionModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = MultichainAssetSelectionInteractor(
            chainFetching: buildChainFetching(flow: flow),
            assetFetching: buildAssetFetching(flow: flow)
        )
        let router = MultichainAssetSelectionRouter()

        let assetFetching = buildAssetFetching(flow: flow)
        let presenter = MultichainAssetSelectionPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: MultichainAssetSelectionViewModelFactoryImpl(),
            logger: Logger.shared,
            selectAssetModuleOutput: selectAssetModuleOutput,
            assetFetching: assetFetching,
            selectedChainAsset: selectedChainAsset
        )
        guard let selectAssetModule = createSelectAssetModule(
            wallet: wallet,
            moduleOutput: presenter,
            contextTag: contextTag,
            selectedChainAsset: selectedChainAsset
        ) else {
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

    private static func buildChainFetching(flow: MultichainChainFetchingFlow) -> MultichainChainFetching {
        let chainsRepository = ChainRepositoryFactory().createAsyncRepository()
        let networkWorker = NetworkWorkerImpl()
        let okxService = OKXDexAggregatorServiceImpl(networkWorker: networkWorker, signer: OKXDexRequestSigner())

        switch flow {
        case let .okxDestination(sourceChainId):
            return CrossChainSwapMultichainChainFetching(chainsRepository: chainsRepository, okxService: okxService, sourceChainId: sourceChainId)
        default:
            return CrossChainSwapMultichainChainFetching(chainsRepository: chainsRepository, okxService: okxService, sourceChainId: nil)
        }
    }

    private static func buildAssetFetching(flow: MultichainChainFetchingFlow) -> MultichainAssetFetching {
        let networkWorker = NetworkWorkerImpl()
        let okxService = OKXDexAggregatorServiceImpl(networkWorker: networkWorker, signer: OKXDexRequestSigner())

        switch flow {
        case let .okxDestination(sourceChainId):
            return OKXMultichainAssetFetching(okxService: okxService, sourceChainId: sourceChainId)
        case .okxSource:
            return OKXMultichainAssetFetching(okxService: okxService, sourceChainId: nil)
        case .preset:
            return OKXMultichainAssetFetching(okxService: okxService, sourceChainId: nil)
        }
    }

    private static func createSelectAssetModule(
        wallet: MetaAccountModel,
        moduleOutput: SelectAssetModuleOutput,
        contextTag: Int? = nil,
        selectedChainAsset: ChainAsset?
    ) -> SelectAssetModuleCreationResult? {
        SelectAssetAssembly.configureModule(
            wallet: wallet,
            selectedAssetId: selectedChainAsset?.asset.id,
            chainAssets: [],
            searchTextsViewModel: .searchAssetPlaceholder,
            output: moduleOutput,
            contextTag: contextTag,
            isEmbed: true
        )
    }
}
