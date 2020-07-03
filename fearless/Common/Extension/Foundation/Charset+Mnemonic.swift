import Foundation

extension CharacterSet {
    static var englishMnemonic: CharacterSet {
        return CharacterSet(charactersIn: "a"..."z")
            .union(.whitespaces)
    }
}
