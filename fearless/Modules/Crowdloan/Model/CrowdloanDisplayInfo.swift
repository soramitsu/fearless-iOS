import Foundation

struct CrowdloanDisplayInfo: Codable, Equatable {
    let paraid: String
    let name: String
    let token: String
    let description: String
    let website: String
    let icon: String
    let rewardRate: Decimal?
    let endingBlock: BlockNumber?
    let disabled: Bool?
    let flow: CustomCrowdloanFlow?
}

extension CrowdloanDisplayInfo {
    var flowIfSupported: CustomCrowdloanFlow? {
        guard let flow = flow else { return nil }
        switch flow {
        case .unsupported: return nil
        default: return flow
        }
    }
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
