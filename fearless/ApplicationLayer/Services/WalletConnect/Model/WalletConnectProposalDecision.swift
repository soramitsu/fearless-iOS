import Foundation
import WalletConnectSign

enum WalletConnectProposalDecision {
    case approve(proposal: Session.Proposal, namespaces: [String: SessionNamespace])
    case reject(proposal: Session.Proposal)
}
