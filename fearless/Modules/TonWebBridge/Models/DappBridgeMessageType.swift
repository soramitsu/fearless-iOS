import Foundation

enum DappBridgeMessageType: String, Codable {
    case invokeRnFunc
    case functionResponse
    case event
}
