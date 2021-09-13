import Foundation
import IrohaCrypto
import FearlessUtils

protocol WebSocketSubscribing {}

protocol WebSocketSubscriptionFactoryProtocol {
    func createSubscriptions(
        address: String,
        type: SNAddressType,
        engine: JSONRPCEngine
    ) throws -> [WebSocketSubscribing]
}
