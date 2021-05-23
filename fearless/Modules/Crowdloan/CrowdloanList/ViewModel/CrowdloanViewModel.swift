import Foundation
import SoraFoundation
import CommonWallet

enum CrowdloanListState {
    case loading
    case loaded(viewModel: CrowdloansViewModel)
    case error(message: String)
    case empty
}

struct CrowdloansViewModel {
    let contributionsCount: String?
    let active: CrowdloansSectionViewModel<ActiveCrowdloanViewModel>?
    let completed: CrowdloansSectionViewModel<CompletedCrowdloanViewModel>?
}

struct CrowdloansSectionViewModel<T> {
    let title: String
    let crowdloans: [CrowdloanSectionItem<T>]
}

struct CrowdloanSectionItem<T> {
    let paraId: ParaId
    let content: T
}

struct ActiveCrowdloanViewModel {
    let title: String
    let timeleft: String
    let description: String
    let progress: String
    let iconViewModel: ImageViewModelProtocol
}

struct CompletedCrowdloanViewModel {
    let title: String
    let description: String
    let progress: String
    let iconViewModel: ImageViewModelProtocol
}
