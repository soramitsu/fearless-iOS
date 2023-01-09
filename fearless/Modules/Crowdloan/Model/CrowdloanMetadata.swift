import Foundation

struct CrowdloanMetadata {
    let blockNumber: BlockNumber
    let blockDuration: BlockTime
    let leasingPeriod: LeasingPeriod
    let leasingOffset: LeasingOffset

    var leasingIndex: LeasingPeriod {
        guard blockNumber >= leasingOffset, leasingPeriod > 0 else {
            return 0
        }

        return (blockNumber - leasingOffset) / leasingPeriod
    }
}
