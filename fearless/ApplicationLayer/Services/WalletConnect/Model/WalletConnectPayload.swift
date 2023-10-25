import Foundation
import Commons
import SSFUtils

struct WalletConnectPayload {
    let address: String?
    let payload: AnyCodable
    let stringRepresentation: String
    let txDetails: JSON
}
