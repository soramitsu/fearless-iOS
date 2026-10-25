import Foundation

public protocol StorageCodingPathProtocol: Equatable, CaseIterable {
    var moduleName: String { get }
    var itemName: String { get }
    var path: (moduleName: String, itemName: String) { get }
}
