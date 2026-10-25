import Foundation

class TupleNodeFactory: TypeNodeFactoryProtocol {
    let parser: TypeParser

    init(parser: TypeParser) {
        self.parser = parser
    }

    func buildNode(from json: JSON, typeName: String, mediator: TypeRegistering) throws -> Node? {
        guard let children = parser.parse(json: json) else {
            return nil
        }

        let internalTypeNames = children.compactMap { $0.stringValue }

        guard internalTypeNames.count == children.count else {
            return nil
        }

        let internalNodes = internalTypeNames.map { typeName in
            mediator.register(typeName: typeName, json: .stringValue(typeName))
        }

        return TupleNode(typeName: typeName, innerNodes: internalNodes)
    }
}
