import Foundation

struct WalletMainContainerViewModel {
    let walletName: String
    let selectedFilter: String
    let selectedFilterImage: ImageViewModelProtocol?
    let address: String?
    let accountScoreViewModel: AccountScoreViewModel?
}
