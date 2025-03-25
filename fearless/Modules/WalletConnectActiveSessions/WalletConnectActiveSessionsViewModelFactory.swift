import Foundation
import WalletConnectSign

protocol WalletConnectActiveSessionsItem {
    var name: String { get }
    var url: URL? { get }
    var icon: URL? { get }
}

protocol WalletConnectActiveSessionsViewModelFactory {
    func createViewModel(
        from sessions: [WalletConnectActiveSessionsItem]
    ) -> [WalletConnectActiveSessionsViewModel]
}

final class WalletConnectActiveSessionsViewModelFactoryImpl: WalletConnectActiveSessionsViewModelFactory {
    func createViewModel(
        from sessions: [WalletConnectActiveSessionsItem]
    ) -> [WalletConnectActiveSessionsViewModel] {
        sessions.map {
            WalletConnectActiveSessionsViewModel(
                name: $0.name,
                host: $0.url?.host,
                icon: RemoteImageViewModel(url: $0.icon)
            )
        }
    }
}
