import Foundation
import SoraFoundation

final class ByteLengthProcessor: TextProcessing {
    let maxLength: Int
    let encoding: String.Encoding

    init(maxLength: Int, encoding: String.Encoding = .utf8) {
        self.maxLength = maxLength
        self.encoding = encoding
    }

    func process(text: String) -> String {
        guard let data = text.data(using: encoding) else {
            return ""
        }

        guard data.count > maxLength else {
            return text
        }

        for index in 0..<maxLength {
            let length = maxLength - index
            if let validString = String(data: data[0..<length], encoding: encoding) {
                return validString
            }
        }

        return ""
    }
}
