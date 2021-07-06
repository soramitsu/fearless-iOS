import Foundation

extension CharacterSet {
    static var englishMnemonic: CharacterSet {
        CharacterSet(charactersIn: "a" ... "z")
            .union(.whitespacesAndNewlines)
    }
}
