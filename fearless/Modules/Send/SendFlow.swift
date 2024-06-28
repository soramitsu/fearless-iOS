import SSFModels
import SSFQRService

enum SendFlowType {
    case token
    case nft
}

enum SendFlowInitialData {
    case chainAsset(ChainAsset)
    case address(String)
    case soraMainnet(qrInfo: SoraQRInfo)
    case bokoloCash(qrInfo: BokoloCashQRInfo)
    case desiredCryptocurrency(qrInfo: DesiredCryptocurrencyQRInfo)

    init(qrInfoType: QRInfoType) {
        switch qrInfoType {
        case let .bokoloCash(bokoloCashQRInfo):
            self = .bokoloCash(qrInfo: bokoloCashQRInfo)
        case let .sora(soraQRInfo):
            self = .soraMainnet(qrInfo: soraQRInfo)
        case let .cex(cexQRInfo):
            self = .address(cexQRInfo.address)
        case let .desiredCryptocurrency(qrInfo):
            self = .desiredCryptocurrency(qrInfo: qrInfo)
        }
    }

    var selectableAsset: Bool {
        switch self {
        case .chainAsset, .address, .desiredCryptocurrency:
            return true
        case .soraMainnet, .bokoloCash:
            return false
        }
    }
}
