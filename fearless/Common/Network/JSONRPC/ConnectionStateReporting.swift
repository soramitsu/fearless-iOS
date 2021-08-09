import Foundation

enum ConnectionState {
    case notConnected
    case connecting(attempt: Int)
    case waitingReconnection(attempt: Int)
    case connected
}

protocol ConnectionStateReporting {
    var state: ConnectionState { get }
}
