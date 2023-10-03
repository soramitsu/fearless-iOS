import Foundation
import SSFUtils

struct CexQRInfo: QRInfo, Equatable {
    let address: String
}

final class CexQREncoder {
    func encode(address: String) throws -> Data {
        guard let data = address.data(using: .utf8) else {
            throw QREncoderError.brokenData
        }
        return data
    }
}

final class CexQRDecoder: QRDecoderProtocol {
    func decode(data: Data) throws -> QRInfoType {
        guard let address = String(data: data, encoding: .utf8) else {
            throw QRDecoderError.brokenFormat
        }

        let substrateAccountId = try? address.toAccountId()
        let ethereumAccountId = try? address.toAccountId()

        guard substrateAccountId != nil || ethereumAccountId != nil else {
            throw QRDecoderError.brokenFormat
        }

        return .cex(CexQRInfo(address: address))
    }
}
