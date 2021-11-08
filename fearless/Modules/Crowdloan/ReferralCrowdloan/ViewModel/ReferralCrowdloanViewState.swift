import Foundation

enum ReferralCrowdloanViewState {
    case loading
    case loadedDefaultFlow(ReferralCrowdloanViewModel)
    case loadedAstarFlow(AstarReferralCrowdloanViewModel)
}
