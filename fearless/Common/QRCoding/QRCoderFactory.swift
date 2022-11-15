import Foundation
import FearlessUtils

public protocol QRCoderFactoryProtocol {
    func createEncoder() -> QREncoderProtocol
    func createDecoder() -> QRDecoderProtocol
}

public protocol QREncoderProtocol {
    func encode(addressInfo: AddressQRInfo) throws -> Data
}

public protocol QRDecoderProtocol {
    func decode(data: Data) throws -> AddressQRInfo
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
    func encode(addressInfo: AddressQRInfo) throws -> Data {
        try AddressQREncoder().encode(info: addressInfo)
    }
}

final class QRDecoder: QRDecoderProtocol {
    private lazy var qrDecoders: [QRDecodable] = [
        NewAddressQRDecoder(),
        CexQRDecoder()
    ]

    func decode(data: Data) throws -> AddressQRInfo {
        let info = qrDecoders.compactMap {
            try? $0.decode(data: data)
        }.first

        guard let info = info as? AddressQRInfo else {
            throw QRDecoderError.wrongDecoder
        }

        return info
    }
}

final class NewAddressQRDecoder: QRDecodable {
    public func decode(data: Data) throws -> QRInfo {
        guard let fields = String(data: data, encoding: .utf8)?
            .components(separatedBy: SubstrateQR.fieldsSeparator) else {
            throw QRDecoderError.brokenFormat
        }

        guard fields.count >= 3, fields.count <= 4 else {
            throw QRDecoderError.unexpectedNumberOfFields
        }

        let prefix = fields[0]
        let address = fields[1]
        let publicKey = try Data(hexString: fields[2])
        let username = fields.count > 3 ? fields[3] : nil

        if address.hasPrefix("0x") {
            return AddressQRInfo(
                address: address,
                rawPublicKey: publicKey,
                username: username
            )
        }

        return AddressQRInfo(
            prefix: prefix,
            address: address,
            rawPublicKey: publicKey,
            username: username
        )
    }
}
