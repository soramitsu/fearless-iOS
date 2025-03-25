import SSFModels
import SSFQRService

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

    var address: String? {
        switch self {
        case .chainAsset:
            return nil
        case let .address(address):
            return address
        case let .soraMainnet(qrInfo: qrInfo):
            return qrInfo.address
        case let .bokoloCash(qrInfo: qrInfo):
            return qrInfo.address
        case let .desiredCryptocurrency(qrInfo: qrInfo):
            return qrInfo.address
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
