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
        BokoloCashDecoder(),
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

final class CexQREncoder {
    public func encode(address: String) throws -> Data {
        guard let data = address.data(using: .utf8) else {
            throw QREncoderError.brokenData
        }
        return data
    }
}
