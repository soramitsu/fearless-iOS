import Foundation

enum CrowdloanAgreementState {
    case loading
    case loaded(viewModel: CrowdloanAgreementViewModel)
    case error
}

struct CrowdloanAgreementViewModel {
    let title: String?
    let agreementText: String?
    let isTermsAgreed: Bool
}

enum CrowdloanAgreementError: Error {
    case invalidAgreementUrl
    case invalidAgreementContents
}
