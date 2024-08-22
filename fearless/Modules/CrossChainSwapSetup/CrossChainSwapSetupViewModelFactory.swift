import Foundation
import SSFModels

protocol CrossChainSwapSetupViewModelFactory {
    func buildNetworkViewModel(chain: ChainModel) -> SelectNetworkViewModel
}

final class CrossChainSwapSetupViewModelFactoryImpl: CrossChainSwapSetupViewModelFactory {
    func buildNetworkViewModel(chain: ChainModel) -> SelectNetworkViewModel {
        let iconViewModel = chain.icon.map { RemoteImageViewModel(url: $0) }
        return SelectNetworkViewModel(
            chainName: chain.name,
            iconViewModel: iconViewModel
        )
    }
}
