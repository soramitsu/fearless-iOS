
import Foundation
import SSFUtils

enum QRMatcherType {
    case qrInfo(QRInfoType)
    case uri(String)

    var address: String? {
        switch self {
        case let .qrInfo(qRInfoType):
            switch qRInfoType {
            case let .solomon(solomonQRInfo):
                return solomonQRInfo.address
            case let .sora(soraQRInfo):
                return soraQRInfo.address
            case let .cex(cexQRInfo):
                return cexQRInfo.address
            case let .bokoloCash(qrInfo):
                return qrInfo.address
            }
        case .uri:
            return nil
        }
    }

    var qrInfo: QRInfoType? {
        switch self {
        case let .qrInfo(qRInfoType):
            return qRInfoType
        case .uri:
            return nil
        }
    }

    var uri: String? {
        switch self {
        case .qrInfo:
            return nil
        case let .uri(uri):
            return uri
        }
    }
}

protocol QRMatcherProtocol {
    func match(code: String) -> QRMatcherType?
}
