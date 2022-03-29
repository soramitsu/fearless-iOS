import Foundation

struct CrowdloanContributionResponse {
    let accountId: AccountId
    let trieOrFundIndex: TrieOrFundIndex
    let contribution: CrowdloanContribution?
}
