import Foundation
import SSFUtils

struct SoraQRInfo: QRInfo, Equatable {
    let prefix: String
    let address: String
    let rawPublicKey: Data
    let username: String
    let assetId: String
    let amount: String?

    init(
        prefix: String = SubstrateQR.prefix,
        address: String,
        rawPublicKey: Data,
        username: String,
        assetId: String,
        amount: String?
    ) {
        self.prefix = prefix
        self.address = address
        self.rawPublicKey = rawPublicKey
        self.username = username
        self.assetId = assetId
        self.amount = amount
    }
}

final class SoraQREncoder {
    private let separator: String

    init(separator: String = SubstrateQR.fieldsSeparator) {
        self.separator = separator
    }

    func encode(addressInfo: SoraQRInfo) throws -> Data {
        let fields: [String] = [
            addressInfo.prefix,
            addressInfo.address,
            addressInfo.rawPublicKey.toHex(includePrefix: true),
            addressInfo.username,
            addressInfo.assetId,
            addressInfo.amount
        ].compactMap { $0 }

        guard let data = fields.joined(separator: separator).data(using: .utf8) else {
            throw QREncoderError.brokenData
        }

        return data
    }
}

final class SoraQRDecoder: QRDecoderProtocol {
    public func decode(data: Data) throws -> QRInfoType {
        guard let decodedString = String(data: data, encoding: .utf8) else {
            throw QRDecoderError.brokenFormat
        }

        let fields = decodedString.components(separatedBy: SubstrateQR.fieldsSeparator)

        guard fields.count >= 3 else {
            throw QRDecoderError.unexpectedNumberOfFields
        }

        let prefix = fields[0]
        let address = fields[1]
        let publicKey = try Data(hexStringSSF: fields[2])
        let username = fields[3]
        let assetId = fields[4]
        let amount = fields[safe: 5]

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
