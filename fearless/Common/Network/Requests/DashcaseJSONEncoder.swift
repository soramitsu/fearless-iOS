import Foundation

class DashcaseJSONEncoder: JSONEncoder {
    private static let dashcaseSymbolString: Character = "-"
    private static let snakecaseSymbolString: Character = "_"

    override init() {
        super.init()

        keyEncodingStrategy = MoonbeamJSONEncoder.convertToDashCase
    }

    static var convertToDashCase: JSONEncoder.KeyEncodingStrategy {
        .custom { codingKeys in

            var key = AnyCodingKey(codingKeys.last!)

            for chr in key.stringValue {
                let str = String(chr)
                if str.lowercased() != str {
                    if let idx = key.stringValue.firstIndex(of: chr) {
                        key.stringValue.replaceSubrange(
                            idx ... idx, with: String(chr).lowercased()
                        )

                        key.stringValue.insert(dashcaseSymbolString, at: idx)
                    }
                }
                if str == String(snakecaseSymbolString) {
                    if let idx = key.stringValue.firstIndex(of: chr) {
                        key.stringValue.replaceSubrange(
                            idx ... idx, with: String(dashcaseSymbolString)
                        )
                    }
                }
            }

            return key
        }
    }
}
