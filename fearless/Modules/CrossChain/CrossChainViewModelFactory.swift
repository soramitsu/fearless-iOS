import Foundation
import SSFUtils
import SSFXCM
import SSFModels

protocol CrossChainViewModelFactoryProtocol {
    func buildNetworkViewModel(chain: ChainModel) -> SelectNetworkViewModel
    func buildRecipientViewModel(address: String, isValid: Bool) -> RecipientViewModel
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

    func buildRecipientViewModel(address: String, isValid: Bool) -> RecipientViewModel {
        RecipientViewModel(
            address: address,
            icon: try? iconGenerator.generateFromAddress(address),
            isValid: isValid
        )
    }
}
