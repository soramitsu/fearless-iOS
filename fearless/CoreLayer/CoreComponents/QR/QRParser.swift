import Foundation
import SSFQRService

protocol QRParser {
    func extractAddress(from code: String) throws -> String
}

final class SubstrateQRParser: QRParser {
    private let prefix: String = SubstrateQRConstants.prefix
    private let separator: String = SubstrateQRConstants.fieldsSeparator

    func extractAddress(from code: String) throws -> String {
        let fields = code
            .components(separatedBy: separator)

        if fields.count == 1 {
            return code
        }

        guard fields.count >= 3, fields.count <= 4 else {
            throw QRDecoderError.unexpectedNumberOfFields
        }

        guard fields[0] == prefix else {
            throw QRDecoderError.undefinedPrefix
        }

        let address = fields[1]

        return address
    }
}
