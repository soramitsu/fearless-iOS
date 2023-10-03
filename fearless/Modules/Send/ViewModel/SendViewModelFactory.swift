import SSFUtils
import SSFModels

protocol SendViewModelFactoryProtocol {
    func buildRecipientViewModel(
        address: String,
        isValid: Bool,
        canEditing: Bool
    ) -> RecipientViewModel
    func buildNetworkViewModel(chain: ChainModel) -> SelectNetworkViewModel
}

final class SendViewModelFactory: SendViewModelFactoryProtocol {
    private let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }

    func buildRecipientViewModel(
        address: String,
        isValid: Bool,
        canEditing: Bool
    ) -> RecipientViewModel {
        RecipientViewModel(
            address: address,
            icon: try? iconGenerator.generateFromAddress(address),
            isValid: isValid,
            canEditing: canEditing
        )
    }

    func buildNetworkViewModel(chain: ChainModel) -> SelectNetworkViewModel {
        let iconViewModel = chain.icon.map { RemoteImageViewModel(url: $0) }
        return SelectNetworkViewModel(
            chainName: chain.name,
            iconViewModel: iconViewModel
        )
    }
}
