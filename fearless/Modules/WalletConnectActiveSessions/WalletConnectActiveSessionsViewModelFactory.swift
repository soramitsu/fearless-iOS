import Foundation
import WalletConnectSign

protocol WalletConnectActiveSessionsViewModelFactory {
    func createViewModel(
        from sessions: [Session]
    ) -> [WalletConnectActiveSessionsViewModel]
}

final class WalletConnectActiveSessionsViewModelFactoryImpl: WalletConnectActiveSessionsViewModelFactory {
    func createViewModel(
        from sessions: [Session]
    ) -> [WalletConnectActiveSessionsViewModel] {
        sessions.map {
            WalletConnectActiveSessionsViewModel(
                name: $0.peer.name,
                host: URL(string: $0.peer.url)?.host,
                icon: RemoteImageViewModel(string: $0.peer.icons.first)
            )
        }
    }
}
