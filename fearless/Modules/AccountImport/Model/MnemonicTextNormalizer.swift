import Foundation
import SoraFoundation

struct MnemonicTextNormalizer: TextProcessing {
    func process(text: String) -> String {
        text
            .split(separator: " ")
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
