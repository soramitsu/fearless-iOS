import Foundation

public class TypeSetParser: TypeParser {
    public let type: String
    public let preprocessor: ParserPreproccessing?
    public let postprocessor: ParserPostprocessing?

    public init(
        type: String,
        preprocessor: ParserPreproccessing?,
        postprocessor: ParserPostprocessing?
    ) {
        self.type = type
        self.preprocessor = preprocessor
        self.postprocessor = postprocessor
    }

    public func parse(json: JSON) -> [JSON]? {
        let preprocessed = preprocessor?.process(json: json) ?? json

        guard case .dictionaryValue = preprocessed else {
            return nil
        }

        guard preprocessed.type?.stringValue == type else {
            return nil
        }

        guard let type = preprocessed.value_type, type.stringValue != nil else {
            return nil
        }

        guard let fields = preprocessed.value_list?.dictValue else {
            return nil
        }

        let resultFields = [type] + fields.reduce([JSON]()) { result, item in
            let json: JSON = .arrayValue([.stringValue(item.key), item.value])
            return result + [json]
        }

        return postprocessor?.process(jsons: resultFields) ?? resultFields
    }
}

public extension TypeSetParser {
    static func generic() -> TypeSetParser {
        let postprocessor = TrimProcessor(charset: .whitespaces)

        return TypeSetParser(
            type: "set",
            preprocessor: nil,
            postprocessor: postprocessor
        )
    }
}
