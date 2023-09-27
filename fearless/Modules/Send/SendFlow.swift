
import SSFModels

enum SendFlowType {
    case token
    case nft
}

enum SendFlowInitialData {
    case chainAsset(ChainAsset)
    case address(String)
    case soraMainnetSolomon(address: String)
    case soraMainnet(qrInfo: SoraQRInfo)
    case bokoloCash(qrInfo: BokoloCashQRInfo)
}
