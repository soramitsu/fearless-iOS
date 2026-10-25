import Foundation

public class TypeValuesParser: TypeParser {
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

        guard let fields = preprocessed.value_list?.arrayValue else {
            return nil
        }

        let validFields = fields.allSatisfy { field in
            field.stringValue != nil
        }

        guard validFields else {
            return nil
        }

        return postprocessor?.process(jsons: fields) ?? fields
    }
}

public extension TypeValuesParser {
    static func enumeration() -> TypeValuesParser {
        let postprocessor = TrimProcessor(charset: .whitespaces)

        return TypeValuesParser(
            type: "enum",
            preprocessor: nil,
            postprocessor: postprocessor
        )
    }
}
