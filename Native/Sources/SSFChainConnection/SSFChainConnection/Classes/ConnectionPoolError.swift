import Foundation

public enum ConnectionPoolError: Error {
    case onlyOneNode
    case connectionFetchingError
}
