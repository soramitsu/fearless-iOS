import Foundation
import WalletConnectSign
import Commons

enum WalletConnectSignDecision {
    case signed(request: Request, signature: AnyCodable)
    case rejected(request: Request, error: JSONRPCError)
}
