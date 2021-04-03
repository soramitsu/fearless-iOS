import Foundation

enum TransactionType: String {
    case incoming = "INCOMING"
    case outgoing = "OUTGOING"
    case reward = "REWARD"
    case slash = "SLASH"
}
