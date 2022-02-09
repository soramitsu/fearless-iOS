import Foundation

struct CrowdloansViewInfo {
    let contributions: CrowdloanContributionDict
    let leaseInfo: ParachainLeaseInfoDict
    let displayInfo: CrowdloanDisplayInfoDict?
    let metadata: CrowdloanMetadata
}
