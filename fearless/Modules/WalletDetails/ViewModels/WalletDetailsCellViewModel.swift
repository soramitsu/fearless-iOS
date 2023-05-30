import UIKit
import SSFModels

struct WalletDetailsCellViewModel {
    let chainImageViewModel: RemoteImageViewModel?
    let account: ChainAccountResponse?
    let chain: ChainModel
    let addressImage: UIImage?
    let address: String?
    let accountMissing: Bool
    let actionsAvailable: Bool
    let locale: Locale?
    let chainUnused: Bool

    var cellInactive: Bool {
        !chain.isSupported || accountMissing
    }
}
