import Foundation
import SoraFoundation
import CommonWallet

enum CrowdloanListState {
    case loading
    case loaded(viewModel: CrowdloansViewModel)
    case error
    case empty
}

struct CrowdloansViewModel {
    let contributionsCount: LocalizableResource<String>?
    let active: CrowdloansSectionViewModel<ActiveCrowdloanViewModel>?
    let completed: CrowdloansSectionViewModel<CompletedCrowdloanViewModel>?
}

struct CrowdloansSectionViewModel<T> {
    let title: LocalizableResource<String>
    let crowdloans: [LocalizableResource<T>]
}

struct ActiveCrowdloanViewModel {
    let title: String
    let timeleft: String
    let description: String
    let progress: String
    let iconViewModel: WalletImageViewModelProtocol
}

struct CompletedCrowdloanViewModel {
    let title: String
    let description: String
    let progress: String
    let iconViewModel: WalletImageViewModelProtocol
}
