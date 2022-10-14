import Foundation

protocol CreateContactViewModelFactoryProtocol {
    func buildViewModel(address: String?, chain: ChainModel) -> CreateContactViewModel
}

final class CreateContactViewModelFactory: CreateContactViewModelFactoryProtocol {
    func buildViewModel(address: String?, chain: ChainModel) -> CreateContactViewModel {
        let iconViewModel = chain.icon.map { RemoteImageViewModel(url: $0) }
        return CreateContactViewModel(
            address: address,
            chainName: chain.name,
            iconViewModel: iconViewModel
        )
    }
}
