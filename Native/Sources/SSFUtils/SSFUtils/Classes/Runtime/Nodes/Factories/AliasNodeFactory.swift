import Foundation

class AliasNodeFactory: TypeNodeFactoryProtocol {
    let parser: TypeParser

    init(parser: TypeParser) {
        self.parser = parser
    }

    func buildNode(from json: JSON, typeName: String, mediator: TypeRegistering) throws -> Node? {
        guard let children = parser.parse(json: json), children.count == 1 else {
            return nil
        }

        guard let child = children.first, let childTypeName = child.stringValue else {
            return nil
        }

        guard childTypeName != typeName else {
            return nil
        }

        return mediator.register(typeName: childTypeName, json: child)
    }
}
