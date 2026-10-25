import Foundation

public enum QRMatcherType {
    case qrInfo(QRInfoType)
    case walletConnect(String)

    public var address: String? {
        switch self {
        case let .qrInfo(qRInfoType):
            switch qRInfoType {
            case let .sora(soraQRInfo):
                return soraQRInfo.address
            case let .cex(cexQRInfo):
                return cexQRInfo.address
            }
        case .walletConnect:
            return nil
        }
    }

    public var qrInfo: QRInfoType? {
        switch self {
        case let .qrInfo(qRInfoType):
            return qRInfoType
        case .walletConnect:
            return nil
        }
    }

    public var uri: String? {
        switch self {
        case .qrInfo:
            return nil
        case let .walletConnect(uri):
            return uri
        }
    }
}
