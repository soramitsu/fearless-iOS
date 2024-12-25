import Foundation
import SSFQRService

final class TonConnectUrlHandling: URLHandlingServiceProtocol {
    private let coordinator = WalletConnectCoordinator.shared
    private lazy var matcher = TonConnectMatcherImpl()
    private lazy var tonConnectService = ServiceAssembly.shared.tonConnectService()

    func handle(url: URL) -> Bool {
        guard let uri = matcher.match(code: url.absoluteString)?.uri else {
            return false
        }

        Task {
            do {
                try await tonConnectService.establishConnection(with: uri)
            } catch {
                Logger.shared.customError(error)
            }
        }

        return true
    }
}
