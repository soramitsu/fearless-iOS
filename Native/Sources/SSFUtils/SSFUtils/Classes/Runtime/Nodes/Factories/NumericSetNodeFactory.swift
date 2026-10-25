import Foundation

class NumericSetNodeFactory: TypeNodeFactoryProtocol {
    let parser: TypeParser

    init(parser: TypeParser) {
        self.parser = parser
    }

    func buildNode(from json: JSON, typeName: String, mediator: TypeRegistering) throws -> Node? {
        guard let items = parser.parse(json: json) else {
            return nil
        }

        guard let itemType = items.first, let itemTypeName = itemType.stringValue else {
            return nil
        }

        let bitVector: [SetNode.Item] = items.dropFirst().compactMap { bitItem in
            guard let components = bitItem.arrayValue,
                  components.count == 2,
                  let name = components.first?.stringValue,
                  let value = components.last?.unsignedIntValue else
            {
                return nil
            }

            return SetNode.Item(name: name, value: value)
        }

        guard bitVector.count == items.count - 1 else {
            return nil
        }

        let itemTypeNode = mediator.register(typeName: itemTypeName, json: itemType)

        return SetNode(typeName: typeName, bitVector: Set(bitVector), itemType: itemTypeNode)
    }
}
