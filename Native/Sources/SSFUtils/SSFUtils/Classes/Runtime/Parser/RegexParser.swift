import Foundation

public class RegexParser: TypeParser {
    let pattern: String
    let preprocessor: ParserPreproccessing?
    let postprocessor: ParserPostprocessing?

    public init(
        pattern: String,
        preprocessor: ParserPreproccessing?,
        postprocessor: ParserPostprocessing?
    ) {
        self.pattern = pattern
        self.preprocessor = preprocessor
        self.postprocessor = postprocessor
    }

    public func parse(json: JSON) -> [JSON]? {
        let preprocessed = preprocessor?.process(json: json) ?? json
        guard let stringValue = preprocessed.stringValue else {
            return nil
        }

        do {
            let expression = try NSRegularExpression(pattern: pattern)

            let nsValue = stringValue as NSString
            let range = NSRange(location: 0, length: nsValue.length)

            if let result = expression.firstMatch(in: stringValue, options: [], range: range),
               result.numberOfRanges > 1
            {
                let jsons: [JSON] = (1 ..< result.numberOfRanges).compactMap { index in
                    let range = result.range(at: index)

                    guard range.location != NSNotFound else {
                        return nil
                    }

                    let value = nsValue.substring(with: result.range(at: index))
                    return .stringValue(value)
                }

                return postprocessor?.process(jsons: jsons) ?? jsons
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
}

public extension RegexParser {
    static func vector() -> RegexParser {
        let trimProcessor = TrimProcessor(charset: .whitespaces)

        return RegexParser(
            pattern: "^Vec<(.+)>$",
            preprocessor: trimProcessor,
            postprocessor: trimProcessor
        )
    }

    static func option() -> RegexParser {
        let trimProcessor = TrimProcessor(charset: .whitespaces)
        return RegexParser(
            pattern: "^Option<(.+)>$",
            preprocessor: trimProcessor,
            postprocessor: trimProcessor
        )
    }

    static func compact() -> RegexParser {
        let trimProcessor = TrimProcessor(charset: .whitespaces)
        return RegexParser(
            pattern: "^Compact<(.+)>$",
            preprocessor: trimProcessor,
            postprocessor: trimProcessor
        )
    }

    static func noiseFilter() -> RegexParser {
        let trimProcessor = TrimProcessor(charset: .whitespaces)
        let pattern = "(T::)|(<T>)|(<T as Trait>::)|(<T as Trait<I>>::)" +
            "|(<T as Config>::)|(\n)|((?:grandpa|session|slashing|schedule)::)"
        return RegexParser(
            pattern: pattern,
            preprocessor: trimProcessor,
            postprocessor: trimProcessor
        )
    }
}
