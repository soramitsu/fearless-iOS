import Foundation
import SSFModels

final class SoraQREncoder {
    private let separator: String

    init(separator: String = SubstrateQRConstants.fieldsSeparator) {
        self.separator = separator
    }

    func encode(addressInfo: SoraQRInfo) throws -> Data {
        let fields: [String] = [
            addressInfo.prefix,
            addressInfo.address,
            addressInfo.rawPublicKey.toHex(includePrefix: true),
            addressInfo.username,
            addressInfo.assetId,
            addressInfo.amount,
        ].compactMap { $0 }

        guard let data = fields.joined(separator: separator).data(using: .utf8) else {
            throw QREncoderError.brokenData
        }

        return data
    }
}

final class SoraQRDecoder: QRDecoder {
    func decode(data: Data) throws -> QRInfoType {
        guard let decodedString = String(data: data, encoding: .utf8) else {
            throw QRDecoderError.brokenFormat
        }

        let fields = decodedString.components(separatedBy: SubstrateQRConstants.fieldsSeparator)

        guard fields.count == 6 else {
            throw QRDecoderError.brokenFormat
        }

        let prefix = fields[0]
        let address = fields[1]
        let publicKey = try Data(hexStringSSF: fields[2])
        let username = fields[3]
        let assetId = fields[4]
        let amount = fields.indices.contains(5) ? fields[5] : nil

        if address.hasPrefix("0x") {
            let qrInfo = SoraQRInfo(
                address: address,
                rawPublicKey: publicKey,
                username: username,
                assetId: assetId,
                amount: amount
            )
            return .sora(qrInfo)
        }

        let qrInfo = SoraQRInfo(
            prefix: prefix,
            address: address,
            rawPublicKey: publicKey,
            username: username,
            assetId: assetId,
            amount: amount
        )
        return .sora(qrInfo)
    }
}
