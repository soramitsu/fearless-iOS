import Foundation
import FearlessUtils

public protocol NewQRCoderFactoryProtocol {
    func createEncoder() -> NewQREncoderProtocol
    func createDecoder() -> NewQRDecoderProtocol
}

public protocol NewQREncoderProtocol {
    func encode(addressInfo: AddressQRInfo) throws -> Data
}

public protocol NewQRDecoderProtocol {
    func decode(data: Data) throws -> AddressQRInfo
}

final class NewQRCoderFactory: NewQRCoderFactoryProtocol {
    func createEncoder() -> NewQREncoderProtocol {
        NewQREncoder()
    }

    func createDecoder() -> NewQRDecoderProtocol {
        NewQRDecoder()
    }
}

final class NewQREncoder: NewQREncoderProtocol {
    func encode(addressInfo: AddressQRInfo) throws -> Data {
        try AddressQREncoder().encode(info: addressInfo)
    }
}

final class NewQRDecoder: NewQRDecoderProtocol {
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
