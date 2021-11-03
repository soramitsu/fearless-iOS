import Foundation
import FearlessUtils

enum CrowdloanAgreementConfirmViewState {
    case normal
    case confirmLoading
}

struct CrowdloanAccountViewModel {
    let accountName: String?
    let accountIcon: DrawableIcon?
}
