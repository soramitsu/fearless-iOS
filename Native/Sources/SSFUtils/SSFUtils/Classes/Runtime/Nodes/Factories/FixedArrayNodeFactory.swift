import Foundation

class FixedArrayNodeFactory: TypeNodeFactoryProtocol {
    let parser: TypeParser

    init(parser: TypeParser) {
        self.parser = parser
    }

    func buildNode(from json: JSON, typeName: String, mediator: TypeRegistering) throws -> Node? {
        guard let children = parser.parse(json: json), children.count == 2 else {
            return nil
        }

        guard let childType = children.first, let childTypeName = childType.stringValue else {
            return nil
        }

        guard let length = children.last?.unsignedIntValue else {
            return nil
        }

        let childNode = mediator.register(typeName: childTypeName, json: childType)

        return FixedArrayNode(
            typeName: typeName,
            elementType: childNode,
            length: length
        )
    }
}
