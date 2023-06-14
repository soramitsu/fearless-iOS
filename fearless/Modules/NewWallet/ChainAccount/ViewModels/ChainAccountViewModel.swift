import Foundation
import SSFModels

struct ChainAccountViewModel {
    let walletName: String
    let selectedChainName: String
    let address: String?
    let assetModel: AssetModel?
    let buyButtonVisible: Bool
    let polkaswapButtonVisible: Bool
    let xcmButtomVisible: Bool
}
