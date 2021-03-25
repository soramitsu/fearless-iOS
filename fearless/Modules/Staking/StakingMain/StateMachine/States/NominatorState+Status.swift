import Foundation
import IrohaCrypto

extension NominatorState {
    var status: NominationViewStatus {
        guard
            let eraStakers = commonData.eraStakersInfo,
            let electionStatus = commonData.electionStatus else {
            return .undefined
        }

        if case .open = electionStatus {
            return .election
        }

        do {
            let accountId = try SS58AddressFactory().accountId(from: stashItem.stash)

            if eraStakers.validators
                .first(where: { $0.exposure.others.contains(where: { $0.who == accountId})}) != nil {
                return .active(era: eraStakers.era)
            }

            if nomination.submittedIn >= eraStakers.era {
                return .waiting
            }

            return .inactive(era: eraStakers.era)

        } catch {
            return .undefined
        }
    }
}
