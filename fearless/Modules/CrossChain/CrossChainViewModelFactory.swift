import Foundation
import FearlessUtils

protocol CrossChainViewModelFactoryProtocol {
    func buildNetworkViewModel(chain: ChainModel) -> SelectNetworkViewModel
}

final class CrossChainViewModelFactory: CrossChainViewModelFactoryProtocol {
    private let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }

    func buildNetworkViewModel(chain: ChainModel) -> SelectNetworkViewModel {
        let iconViewModel = chain.icon.map { RemoteImageViewModel(url: $0) }
        return SelectNetworkViewModel(
            chainName: chain.name,
            iconViewModel: iconViewModel
        )
    }
}
