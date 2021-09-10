import Foundation

extension String {
    var displayCall: String {
        replacingSnakeCase().replacingCamelCase().capitalized
    }

    var displayModule: String {
        replacingSnakeCase().replacingCamelCase().capitalized
    }

    func replacingSnakeCase() -> String {
        replacingOccurrences(of: "_", with: " ")
    }

    func replacingCamelCase() -> String {
        var replacedCamelCase: String = ""
        let upperCase = CharacterSet.uppercaseLetters
        for scalar in unicodeScalars {
            if upperCase.contains(scalar) {
                replacedCamelCase.append(" ")
            }

            let character = Character(scalar)
            replacedCamelCase.append(character)
        }

        return replacedCamelCase
    }
}
