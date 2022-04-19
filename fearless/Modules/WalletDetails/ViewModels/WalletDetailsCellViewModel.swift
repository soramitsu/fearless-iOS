import UIKit

struct WalletDetailsCellViewModel {
    let chainImageViewModel: RemoteImageViewModel?
    let account: ChainAccountResponse?
    let chain: ChainModel
    let addressImage: UIImage?
    let address: String?
    let accountMissing: Bool
    let actionsAvailable: Bool

    var chainAccount: ChainAccountInfo? {
        guard let account = account else {
            return nil
        }

        return ChainAccountInfo(chain: chain, account: account)
    }
}
