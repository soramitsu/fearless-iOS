import Foundation

struct CrowdloanDisplayInfo: Codable, Equatable {
    static func == (lhs: CrowdloanDisplayInfo, rhs: CrowdloanDisplayInfo) -> Bool {
        lhs.paraid == rhs.paraid
    }

    let paraid: String
    let name: String
    let token: String
    let description: String
    let website: String
    let icon: String
    let rewardRate: Decimal?
    let flow: CustomCrowdloanFlow?
}

typealias CrowdloanDisplayInfoList = [CrowdloanDisplayInfo]
typealias CrowdloanDisplayInfoDict = [ParaId: CrowdloanDisplayInfo]

extension CrowdloanDisplayInfoList {
    func toMap() -> CrowdloanDisplayInfoDict {
        reduce(into: CrowdloanDisplayInfoDict()) { dict, info in
            guard let paraId = ParaId(info.paraid) else {
                return
            }

            dict[paraId] = info
        }
    }
}
