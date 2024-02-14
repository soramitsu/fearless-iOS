import Foundation

protocol NetworkClientFactory {
    func buildNetworkClient(with type: NetworkClientType) -> NetworkClient
}

final class BaseNetworkClientFactory: NetworkClientFactory {
    func buildNetworkClient(with type: NetworkClientType) -> NetworkClient {
        switch type {
        case .plain:
            return RESTNetworkClient(session: URLSession.shared)
        case let .custom(client):
            return client
        }
    }
}
