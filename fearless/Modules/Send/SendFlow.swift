
import SSFModels

enum SendFlowType {
    case token
    case nft
}

enum SendFlowInitialData {
    case chainAsset(ChainAsset)
    case address(String)
    case soraMainnet(qrInfo: SoraQRInfo)
    case bokoloCash(qrInfo: BokoloCashQRInfo)

    init(qrInfoType: QRInfoType) {
        switch qrInfoType {
        case let .bokoloCash(bokoloCashQRInfo):
            self = .bokoloCash(qrInfo: bokoloCashQRInfo)
        case let .sora(soraQRInfo):
            self = .soraMainnet(qrInfo: soraQRInfo)
        case let .cex(cexQRInfo):
            self = .address(cexQRInfo.address)
        }
    }

    var selectableAsset: Bool {
        switch self {
        case .chainAsset, .address:
            return true
        case .soraMainnet, .bokoloCash:
            return false
        }
    }
}
