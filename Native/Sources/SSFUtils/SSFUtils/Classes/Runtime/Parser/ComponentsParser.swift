import Foundation

public struct Bracket: Hashable {
    public let left: Character
    public let right: Character

    public init(left: Character, right: Character) {
        self.left = left
        self.right = right
    }
}

public class ComponentsParser: TypeParser {
    public let separator: Character
    public let mainBracket: Bracket
    public let internalBrackets: Set<Bracket>
    public let preprocessor: ParserPreproccessing?
    public let postprocessor: ParserPostprocessing?

    public init(
        mainBracket: Bracket,
        separator: Character,
        internalBrackets: Set<Bracket>,
        preprocessor: ParserPreproccessing?,
        postprocessor: ParserPostprocessing?
    ) {
        self.mainBracket = mainBracket
        self.separator = separator
        self.internalBrackets = internalBrackets
        self.preprocessor = preprocessor
        self.postprocessor = postprocessor
    }

    public func parse(json: JSON) -> [JSON]? {
        let preprocessed = preprocessor?.process(json: json) ?? json

        guard let tokens = preprocessed.stringValue else {
            return nil
        }

        guard tokens.hasPrefix(String(mainBracket.left)),
              tokens.hasSuffix(String(mainBracket.right)) else
        {
            return nil
        }

        var components: [String] = []
        var partial = ""
        var waiting: [Bracket] = []

        for (index, token) in tokens.enumerated() where index > 0 && index < tokens.count - 1 {
            if token == separator {
                if waiting.isEmpty {
                    components.append(partial)
                    partial.removeAll()
                } else {
                    partial.append(token)
                }
            } else if let bracket = internalBrackets.first(where: { $0.left == token }) {
                waiting.append(bracket)
                partial.append(token)
            } else if let bracket = internalBrackets.first(where: { $0.right == token }) {
                if waiting.popLast()?.right != bracket.right {
                    return nil
                }

                partial.append(token)
            } else {
                partial.append(token)
            }
        }

        guard waiting.isEmpty else {
            return nil
        }

        components.append(partial)

        guard components.allSatisfy({ !$0.isEmpty }) else {
            return nil
        }

        let result = components.map { JSON.stringValue($0) }

        return postprocessor?.process(jsons: result) ?? result
    }
}

public extension ComponentsParser {
    static func tuple() -> ComponentsParser {
        let trimProcessor = TrimProcessor(charset: .whitespaces)
        return ComponentsParser(
            mainBracket: Bracket(left: "(", right: ")"),
            separator: ",",
            internalBrackets: [
                Bracket(left: "(", right: ")"),
                Bracket(left: "<", right: ">"),
                Bracket(left: "[", right: "]"),
            ],
            preprocessor: trimProcessor,
            postprocessor: trimProcessor
        )
    }
}
