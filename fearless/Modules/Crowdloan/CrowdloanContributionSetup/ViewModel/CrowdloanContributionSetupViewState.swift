import Foundation
import CommonWallet

enum CrowdloanContributionSetupViewState {
    case loading(CrowdloanContributionSetupViewModel?)
    case loadedDefaultFlow(CrowdloanContributionSetupViewModel)
    case loadedAcalaFlow(AcalaCrowdloanContributionSetupViewModel)
    case loadedMoonbeamFlow(MoonbeamCrowdloanContributionSetupViewModel)
}
