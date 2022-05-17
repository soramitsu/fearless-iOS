import Foundation

protocol RemoteImageViewModelFactoryProtocol {
    func buildRemoteImageViewModel(url: URL) -> RemoteImageViewModel
}

extension RemoteImageViewModelFactoryProtocol {
    func buildRemoteImageViewModel(url: URL) -> RemoteImageViewModel {
        RemoteImageViewModel(url: url)
    }
}
