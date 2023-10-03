import Foundation
// import SSFUtils

protocol QRCoderFactoryProtocol {
    func createEncoder() -> QREncoderProtocol
    func createDecoder() -> QRDecoderProtocol
}

protocol QREncoderProtocol {
    func encode(with type: QRType) throws -> Data
}

enum QRInfoType {
    case solomon(SolomonQRInfo)
    case sora(SoraQRInfo)
    case cex(CexQRInfo)
}

protocol QRDecoderProtocol {
    func decode(data: Data) throws -> QRInfoType
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
    private lazy var qrDecoders: [QRDecoderProtocol] = [
        SolomonQRDecoder(),
        SoraQRDecoder(),
        CexQRDecoder()
    ]

    func decode(data: Data) throws -> QRInfoType {
        let types = qrDecoders.compactMap {
            try? $0.decode(data: data)
        }
        guard
            types.count == 1,
            let infoType = types.first
        else {
            throw ConvenienceError(error: "Qr must have one coincidence")
        }

        return infoType
    }
}
