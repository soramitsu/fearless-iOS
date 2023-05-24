import Foundation

struct ChainAccountViewModel {
    let walletName: String
    let selectedChainName: String
    let address: String?
    let chainAssetModel: ChainAssetModel?
    let buyButtonVisible: Bool
    let polkaswapButtonVisible: Bool
    let xcmButtomVisible: Bool
}
