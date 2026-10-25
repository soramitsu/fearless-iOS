import Foundation

class EnumValuesNodeFactory: TypeNodeFactoryProtocol {
    let parser: TypeParser

    init(parser: TypeParser) {
        self.parser = parser
    }

    func buildNode(from json: JSON, typeName: String, mediator _: TypeRegistering) throws -> Node? {
        guard let children = parser.parse(json: json) else {
            return nil
        }

        let childrenNodes: [String] = try children.map { child in
            guard let caseName = child.stringValue else {
                throw TypeNodeFactoryError.unexpectedParsingResult(typeName: typeName)
            }

            return caseName
        }

        return EnumValuesNode(typeName: typeName, values: childrenNodes)
    }
}
