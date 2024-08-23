import Foundation
import SSFModels

protocol MultichainAssetSelectionViewModelFactory {
    func buildViewModels(chains: [ChainModel], selectedChainId: ChainModel.Id?) -> [ChainSelectionCollectionCellModel]
}

final class MultichainAssetSelectionViewModelFactoryImpl: MultichainAssetSelectionViewModelFactory {
    func buildViewModels(chains: [SSFModels.ChainModel], selectedChainId: ChainModel.Id?) -> [ChainSelectionCollectionCellModel] {
        chains.map {
            let imageViewModel = RemoteImageViewModel(url: $0.icon)
            return ChainSelectionCollectionCellModel(chain: $0, imageViewModel: imageViewModel, selected: selectedChainId == $0.chainId)
        }
    }
}
