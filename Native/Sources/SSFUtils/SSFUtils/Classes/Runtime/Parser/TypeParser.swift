import Foundation

public protocol TypeParser {
    func parse(json: JSON) -> [JSON]?
}

public protocol ParserPreproccessing {
    func process(json: JSON) -> JSON
}

public protocol ParserPostprocessing {
    func process(jsons: [JSON]?) -> [JSON]?
}
