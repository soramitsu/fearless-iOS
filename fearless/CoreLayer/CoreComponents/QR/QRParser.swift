import Foundation
import FearlessUtils

protocol QRParser {
    func extractAddress(from code: String) throws -> String
}

final class SubstrateQRParser: QRParser {
    private let prefix: String = SubstrateQR.prefix
    private let separator: String = SubstrateQR.fieldsSeparator

    func extractAddress(from code: String) throws -> String {
        let fields = code
            .components(separatedBy: separator)

        guard fields.count >= 3, fields.count <= 4 else {
            throw SubstrateQRDecoderError.unexpectedNumberOfFields
        }

        guard fields[0] == prefix else {
            throw SubstrateQRDecoderError.undefinedPrefix
        }

        let address = fields[1]

        return address
    }
}
