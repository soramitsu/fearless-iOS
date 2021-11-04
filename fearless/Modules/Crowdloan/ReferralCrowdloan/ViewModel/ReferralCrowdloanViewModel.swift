import Foundation

struct ReferralCrowdloanViewModel {
    let bonusPercentage: String
    let bonusValue: String
    let canApplyDefaultCode: Bool
    let isTermsAgreed: Bool
    let isCodeReceived: Bool
    let customFlow: CustomCrowdloanFlow?

    var regularBonusViewVisible: Bool {
        switch customFlow {
        case .astar: return false
        default: return true
        }
    }

    var myBonusViewVisible: Bool {
        switch customFlow {
        case .astar: return true
        default: return false
        }
    }

    var friendBonusViewVisible: Bool {
        switch customFlow {
        case .astar: return true
        default: return false
        }
    }

    var privacyPolicyAgreementVisible: Bool {
        switch customFlow {
        case .astar: return false
        default: return true
        }
    }
}
