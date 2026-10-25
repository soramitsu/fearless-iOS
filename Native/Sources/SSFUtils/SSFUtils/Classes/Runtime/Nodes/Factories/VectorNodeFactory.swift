import Foundation

class VectorNodeFactory: TypeNodeFactoryProtocol {
    let parser: TypeParser

    init(parser: TypeParser) {
        self.parser = parser
    }

    func buildNode(from json: JSON, typeName: String, mediator: TypeRegistering) throws -> Node? {
        guard let child = parser.parse(json: json)?.first else {
            return nil
        }

        guard let childTypeName = child.stringValue else {
            return nil
        }

        let childNode = mediator.register(typeName: childTypeName, json: child)

        return VectorNode(typeName: typeName, underlying: childNode)
    }
}
