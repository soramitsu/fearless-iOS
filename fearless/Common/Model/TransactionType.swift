import Foundation

enum TransactionType: String, CaseIterable {
    case incoming = "Incoming"
    case outgoing = "Outgoing"
    case reward = "Reward"
    case slash = "Slash"
    case extrinsic = "Extrinsic"
    case swap = "Swap"
    case unused
}
