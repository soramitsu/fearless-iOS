import Foundation

public class TrimProcessor: ParserPreproccessing, ParserPostprocessing {
    public let charset: CharacterSet

    init(charset: CharacterSet) {
        self.charset = charset
    }

    public func process(json: JSON) -> JSON {
        guard let stringValue = json.stringValue else {
            return json
        }

        let result = stringValue.trimmingCharacters(in: charset)

        return .stringValue(result)
    }

    public func process(jsons: [JSON]?) -> [JSON]? {
        jsons?.map { process(json: $0) }
    }
}
