import Foundation

typealias CrowdloanContributionDict = [TrieOrFundIndex: CrowdloanContribution]

extension Array where Element == CrowdloanContributionResponse {
    func toDict() -> CrowdloanContributionDict {
        reduce(into: CrowdloanContributionDict()) { result, response in
            if let value = response.contribution {
                result[response.trieOrFundIndex] = value
            }
        }
    }
}
