import Foundation

struct CrowdloanContributionResponse {
    let address: AccountAddress
    let trieIndex: TrieIndex
    let contribution: CrowdloanContribution?
}
