import Foundation
import IrohaCrypto

protocol WebSocketServiceProtocol: ApplicationServiceProtocol {
    var connection: JSONRPCEngine? { get }

    func update(settings: WebSocketServiceSettings)
}

struct WebSocketServiceSettings: Equatable {
    let url: URL
    let addressType: SNAddressType?
    let address: String?
}
