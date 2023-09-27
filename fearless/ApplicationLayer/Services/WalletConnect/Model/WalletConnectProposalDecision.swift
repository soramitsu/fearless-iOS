import Foundation
import WalletConnectSign
// import WalletConnectSwiftV2

enum WalletConnectProposalDecision {
    case approve(proposal: Session.Proposal, namespaces: [String: SessionNamespace])
    case reject(proposal: Session.Proposal)
}
