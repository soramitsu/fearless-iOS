import Foundation

enum ReferralCrowdloanViewState {
    case loading
    case loadedDefaultFlow(ReferralCrowdloanViewModel)
    case loadedAstarFlow(AstarReferralCrowdloanViewModel)
    case loadedAcalaFlow(AcalaReferralCrowdloanViewModel)
}
