import Foundation

class OneOfTypeNodeFactory: TypeNodeFactoryProtocol {
    let children: [TypeNodeFactoryProtocol]

    init(children: [TypeNodeFactoryProtocol]) {
        self.children = children
    }

    func buildNode(from json: JSON, typeName: String, mediator: TypeRegistering) throws -> Node? {
        for child in children {
            if let node = try child.buildNode(from: json, typeName: typeName, mediator: mediator) {
                return node
            }
        }

        return nil
    }
}
