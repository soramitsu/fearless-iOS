import Foundation

public protocol Node: AnyObject, DynamicScaleCodable {
    var typeName: String { get }
}

public struct NameNode {
    public let name: String
    public let node: Node
    public let index: UInt8

    init(name: String, node: Node, index: Int) {
        self.name = name
        self.node = node
        self.index = UInt8(index)
    }

    init(name: String, node: Node, index: UInt8) {
        self.name = name
        self.node = node
        self.index = index
    }
}
