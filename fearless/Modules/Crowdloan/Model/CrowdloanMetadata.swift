import Foundation

struct CrowdloanMetadata {
    let blockNumber: BlockNumber
    let blockDuration: BlockTime
    let leasingPeriod: LeasingPeriod

    var leasingIndex: LeasingPeriod {
        leasingPeriod > 0 ? blockNumber / leasingPeriod : 0
    }
}
