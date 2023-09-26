import Foundation
import SSFUtils

protocol QRCoderFactoryProtocol {
    func createEncoder() -> QREncoderProtocol
    func createDecoder() -> QRDecoderProtocol
}

protocol QREncoderProtocol {
    func encode(with type: QRType) throws -> Data
}

protocol QRDecoderProtocol {
    func decode(data: Data) throws -> QRInfo
}

enum QRType {
    case address(String)
    case addressInfo(SoraQRInfo)
}

final class QRCoderFactory: QRCoderFactoryProtocol {
    func createEncoder() -> QREncoderProtocol {
        QREncoder()
    }

    func createDecoder() -> QRDecoderProtocol {
        QRDecoder()
    }
}

final class QREncoder: QREncoderProtocol {
    func encode(with type: QRType) throws -> Data {
        switch type {
        case let .address(address):
            return try CexQREncoder().encode(address: address)
        case let .addressInfo(addressInfo):
            return try SoraQREncoder().encode(addressInfo: addressInfo)
        }
    }
}

final class QRDecoder: QRDecoderProtocol {
    private lazy var qrDecoders: [QRDecodable] = [
        SolomonQRDecoder(),
        SoraQRDecoder(),
        CexQRDecoder()
    ]

    func decode(data: Data) throws -> QRInfo {
        let info = qrDecoders.compactMap {
            try? $0.decode(data: data)
        }.first

        guard let info = info else {
            throw QRDecoderError.wrongDecoder
        }

        return info
    }
}

struct SoraQRInfo: QRInfo, Equatable {
    public let prefix: String
    public let address: String
    public let rawPublicKey: Data
    public let username: String?
    public let assetId: String

    init(
        prefix: String = SubstrateQR.prefix,
        address: String,
        rawPublicKey: Data,
        username: String?,
        assetId: String
    ) {
        self.prefix = prefix
        self.address = address
        self.rawPublicKey = rawPublicKey
        self.username = username
        self.assetId = assetId
    }
}

final class CexQREncoder {
    public func encode(address: String) throws -> Data {
        guard let data = address.data(using: .utf8) else {
            throw QREncoderError.brokenData
        }
        return data
    }
}

final class SoraQREncoder {
    let separator: String

    public init(separator: String = SubstrateQR.fieldsSeparator) {
        self.separator = separator
    }

    public func encode(addressInfo: SoraQRInfo) throws -> Data {
        let fields: [String] = [
            addressInfo.prefix,
            addressInfo.address,
            addressInfo.rawPublicKey.toHex(includePrefix: true),
            "",
            addressInfo.assetId
        ]

        guard let data = fields.joined(separator: separator).data(using: .utf8) else {
            throw QREncoderError.brokenData
        }

        return data
    }
}

final class SoraQRDecoder: QRDecodable {
    public func decode(data: Data) throws -> QRInfo {
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
        let username = fields.count > 3 ? fields[3] : nil
        let assetId = fields[4]

        if address.hasPrefix("0x") {
            return SoraQRInfo(
                address: address,
                rawPublicKey: publicKey,
                username: username,
                assetId: assetId
            )
        }

        return SoraQRInfo(
            prefix: prefix,
            address: address,
            rawPublicKey: publicKey,
            username: username,
            assetId: assetId
        )
    }
}
