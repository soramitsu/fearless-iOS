import Foundation

public protocol ChainConnectionProtocol {
    associatedtype T
    var isActive: Bool { get }
    func connection() throws -> T
}
