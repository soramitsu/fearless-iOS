import Foundation

protocol RemoteImageViewModelFactoryProtocol {
    func buildRemoteImageViewModel(chain: ChainModel) -> RemoteImageViewModel
}

extension RemoteImageViewModelFactoryProtocol {
    func buildRemoteImageViewModel(chain: ChainModel) -> RemoteImageViewModel {
        RemoteImageViewModel(url: chain.icon)
    }
}
