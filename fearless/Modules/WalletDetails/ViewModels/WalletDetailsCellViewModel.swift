import UIKit

struct WalletDetailsCellViewModel {
    let chainImageViewModel: RemoteImageViewModel?
    let chain: ChainModel
    let addressImage: UIImage?
    let address: String?
    let accountMissing: Bool
}
