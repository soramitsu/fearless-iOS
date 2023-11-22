import Foundation
import SSFModels

struct AssetNetworksTableCellModel {
    let iconViewModel: RemoteImageViewModel?
    let chainNameLabelText: String?
    let cryptoBalanceLabelText: String?
    let fiatBalanceLabelText: String?
    let chainAsset: ChainAsset
}
