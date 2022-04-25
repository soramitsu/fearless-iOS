import Foundation
import CommonWallet

public protocol QREncoderProtocol {
    func encode(receiverInfo: ReceiveInfo) throws -> Data
}

public protocol QRDecoderProtocol {
    func decode(data: Data) throws -> ReceiveInfo
}

public protocol QRCoderFactoryProtocol {
    func createEncoder() -> QREncoderProtocol
    func createDecoder() -> QRDecoderProtocol
}

public struct QREncoder: QREncoderProtocol {
    public init() {}
    let underlyingEncoder = JSONEncoder()

    public func encode(receiverInfo: ReceiveInfo) throws -> Data {
        try underlyingEncoder.encode(receiverInfo)
    }
}

struct QRDecoder: QRDecoderProtocol {
    let underlyingDecoder = JSONDecoder()

    func decode(data: Data) throws -> ReceiveInfo {
        try underlyingDecoder.decode(ReceiveInfo.self, from: data)
    }
}

struct QRCoderFactory: QRCoderFactoryProtocol {
    func createEncoder() -> QREncoderProtocol {
        QREncoder()
    }

    func createDecoder() -> QRDecoderProtocol {
        QRDecoder()
    }
}
