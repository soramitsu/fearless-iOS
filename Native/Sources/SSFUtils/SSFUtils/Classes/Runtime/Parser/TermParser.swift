import Foundation

public class TermParser: TypeParser {
    public let preprocessor: ParserPreproccessing?
    public let postprocessor: ParserPostprocessing?

    public init(
        preprocessor: ParserPreproccessing?,
        postprocessor: ParserPostprocessing?
    ) {
        self.preprocessor = preprocessor
        self.postprocessor = postprocessor
    }

    public func parse(json: JSON) -> [JSON]? {
        let preprocessed = preprocessor?.process(json: json) ?? json

        guard preprocessed.stringValue != nil else {
            return nil
        }

        let result = [preprocessed]

        return postprocessor?.process(jsons: result) ?? result
    }
}

public extension TermParser {
    static func generic() -> TermParser {
        let trim = TrimProcessor(charset: .whitespaces)

        return TermParser(
            preprocessor: trim,
            postprocessor: trim
        )
    }
}
