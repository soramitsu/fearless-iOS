import Foundation

struct CrowdloanContributionResponse {
    let address: AccountAddress
    let trieIndex: UInt32
    let contribution: CrowdloanContribution?
}
