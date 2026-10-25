import Foundation

public class TypeMappingParser: TypeParser {
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

        guard let fields = preprocessed.type_mapping?.arrayValue else {
            return nil
        }

        let validFields = fields.allSatisfy { field in
            guard let list = field.arrayValue, list.count == 2 else {
                return false
            }

            guard list.first?.stringValue != nil else {
                return false
            }

            return true
        }

        guard validFields else {
            return nil
        }

        return postprocessor?.process(jsons: fields) ?? fields
    }
}

public extension TypeMappingParser {
    static func structure() -> TypeMappingParser {
        let postprocessor = TrimProcessor(charset: .whitespaces)

        return TypeMappingParser(
            type: "struct",
            preprocessor: nil,
            postprocessor: postprocessor
        )
    }

    static func enumeration() -> TypeMappingParser {
        let postprocessor = TrimProcessor(charset: .whitespaces)

        return TypeMappingParser(
            type: "enum",
            preprocessor: nil,
            postprocessor: postprocessor
        )
    }
}
