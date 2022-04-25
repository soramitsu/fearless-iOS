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
    let tokenSymbol: String
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

typealias CrowdloanActiveSection = CrowdloanSectionItem<ActiveCrowdloanViewModel>
typealias CrowdloanCompletedSection = CrowdloanSectionItem<CompletedCrowdloanViewModel>

enum CrowdloanDescViewModel {
    case address(_ address: String)
    case text(_ text: String)
}

struct ActiveCrowdloanViewModel {
    let title: String
    let timeleft: String
    let description: CrowdloanDescViewModel
    let progress: String
    let iconViewModel: ImageViewModelProtocol
    let contribution: String?
}

struct CompletedCrowdloanViewModel {
    let title: String
    let description: CrowdloanDescViewModel
    let progress: String
    let iconViewModel: ImageViewModelProtocol
    let contribution: String?
}
