import Foundation

enum TypeNodeFactoryError: Error {
    case unexpectedParsingResult(typeName: String)
}

protocol TypeNodeFactoryProtocol {
    func buildNode(from json: JSON, typeName: String, mediator: TypeRegistering) throws -> Node?
}
