import Foundation
import IrohaCrypto

protocol WebSocketSubscribing {}

protocol WebSocketSubscriptionFactoryProtocol {
    func createSubscriptions(address: String,
                             type: SNAddressType,
                             engine: JSONRPCEngine) throws -> [WebSocketSubscribing]
}
