import Foundation
import Commons
import SSFUtils
import SSFModels

struct WalletConnectPayload {
    let address: String
    let payload: AnyCodable
    let stringRepresentation: String
}
