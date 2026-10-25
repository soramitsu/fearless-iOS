import Foundation

// sourcery: AutoMockable
public protocol QRDecoder {
    func decode(data: Data) throws -> QRInfoType
}

final class QRDecoderDefault: QRDecoder {
    static let defaultDecoders: [QRDecoder] = [
        SoraQRDecoder(),
        CexQRDecoder(),
    ]

    private let qrDecoders: [QRDecoder]

    init(qrDecoders: [QRDecoder] = QRDecoderDefault.defaultDecoders) {
        self.qrDecoders = qrDecoders
    }

    func decode(data: Data) throws -> QRInfoType {
        let types = qrDecoders.compactMap {
            try? $0.decode(data: data)
        }
        guard types.count == 1,
              let infoType = types.first else
        {
            throw QRDecoderError.manyCoincidence
        }

        return infoType
    }
}
