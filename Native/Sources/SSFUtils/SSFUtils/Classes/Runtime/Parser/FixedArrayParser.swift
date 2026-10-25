import Foundation

public class FixedArrayParser: TypeParser {
    public let componentsParser: TypeParser
    public let lengthParser: TypeParser

    public init(componentsParser: TypeParser, lengthParser: TypeParser) {
        self.componentsParser = componentsParser
        self.lengthParser = lengthParser
    }

    public func parse(json: JSON) -> [JSON]? {
        guard let components = componentsParser.parse(json: json) else {
            return nil
        }

        guard components.count == 2, components.allSatisfy({ $0.stringValue != nil }) else {
            return nil
        }

        guard let elementType = components.first else {
            return nil
        }

        guard let lengthJson = components.last,
              let lengthStr = lengthParser.parse(json: lengthJson)?.first?.stringValue,
              let lengthValue = UInt64(lengthStr) else
        {
            return nil
        }

        let length = JSON.unsignedIntValue(lengthValue)

        return [elementType, length]
    }
}

public extension FixedArrayParser {
    static func generic() -> FixedArrayParser {
        let trimProcessor = TrimProcessor(charset: .whitespaces)
        let componentsParser = ComponentsParser(
            mainBracket: Bracket(left: "[", right: "]"),
            separator: ";",
            internalBrackets: [
                Bracket(left: "[", right: "]"),
                Bracket(left: "(", right: ")"),
                Bracket(left: "<", right: ">"),
            ],
            preprocessor: trimProcessor,
            postprocessor: trimProcessor
        )

        let lengthParser = RegexParser(
            pattern: "^(0|(?:[1-9]\\d*))$",
            preprocessor: trimProcessor,
            postprocessor: trimProcessor
        )

        return FixedArrayParser(
            componentsParser: componentsParser,
            lengthParser: lengthParser
        )
    }
}
