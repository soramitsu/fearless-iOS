import Foundation

class EnumNodeFactory: TypeNodeFactoryProtocol {
    let parser: TypeParser

    init(parser: TypeParser) {
        self.parser = parser
    }

    func buildNode(from json: JSON, typeName: String, mediator: TypeRegistering) throws -> Node? {
        guard let children = parser.parse(json: json) else {
            return nil
        }

        let childrenNodes: [NameNode] = try children.enumerated().map { index, child in
            guard let nameAndValueType = child.arrayValue,
                  nameAndValueType.count == 2,
                  let name = nameAndValueType.first?.stringValue,
                  let value = nameAndValueType.last,
                  let valueTypeName = value.stringValue else
            {
                throw TypeNodeFactoryError.unexpectedParsingResult(typeName: typeName)
            }

            let node = mediator.register(typeName: valueTypeName, json: value)

            return NameNode(name: name, node: node, index: index)
        }

        return EnumNode(typeName: typeName, typeMapping: childrenNodes)
    }
}
