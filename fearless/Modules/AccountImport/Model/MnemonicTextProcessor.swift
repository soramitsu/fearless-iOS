import Foundation
import SoraFoundation

struct MnemonicTextProcessor: TextProcessing {
    func process(text: String) -> String {
        let cuttedTabAndLineBreaks = text
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\t", with: "")
        var result = cuttedTabAndLineBreaks
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        let setOfWords = result.split(separator: " ")
        if setOfWords.count == 12 {
            return result.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
        return result
    }
}
