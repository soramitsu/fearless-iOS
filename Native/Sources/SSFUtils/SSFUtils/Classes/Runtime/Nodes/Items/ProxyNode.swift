import Foundation

public protocol NodeResolver: AnyObject {
    func resolve(for key: String) -> Node?
}

public class ProxyNode: Node {
    public let typeName: String
    public weak var resolver: NodeResolver?

    public init(typeName: String, resolver: NodeResolver) {
        self.typeName = typeName
        self.resolver = resolver
    }

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        guard let underlyingNode = resolver?.resolve(for: typeName) else {
            throw DynamicScaleCoderError.unresolvedType(name: typeName)
        }

        if underlyingNode is GenericNode {
            try encoder.append(json: value, type: typeName)
        } else {
            try underlyingNode.accept(encoder: encoder, value: value)
        }
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        guard let underlyingNode = resolver?.resolve(for: typeName) else {
            throw DynamicScaleCoderError.unresolvedType(name: typeName)
        }

        if underlyingNode is GenericNode {
            return try decoder.read(type: typeName)
        } else {
            return try underlyingNode.accept(decoder: decoder)
        }
    }
}
