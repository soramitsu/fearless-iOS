import Foundation
import SoraFoundation

struct StakingMainViewModel {
    let address: String
    let chainName: String
    let assetName: String
    let assetIcon: ImageViewModelProtocol?
    let balanceViewModel: LocalizableResource<String>?
}
