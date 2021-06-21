import Foundation

typealias CrowdloanContributionDict = [TrieIndex: CrowdloanContribution]

extension Array where Element == CrowdloanContributionResponse {
    func toDict() -> CrowdloanContributionDict {
        reduce(into: CrowdloanContributionDict()) { result, response in
            if let value = response.contribution {
                result[response.trieIndex] = value
            }
        }
    }
}
