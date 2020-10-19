import Foundation

protocol WebSocketServiceProtocol: ApplicationServiceProtocol {
    var connection: JSONRPCEngine? { get }

    func update(url: URL)
}
