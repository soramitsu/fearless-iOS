import Foundation

struct Crowdloan {
    let paraId: ParaId
    let fundInfo: CrowdloanFunds
}

extension Crowdloan {
    func isCompleted(for metadata: CrowdloanMetadata) -> Bool {
        metadata.blockNumber >= fundInfo.end || metadata.leasingIndex > fundInfo.firstPeriod
    }

    func remainedTime(at blockNumber: BlockNumber, blockDuration: BlockTime) -> TimeInterval {
        guard fundInfo.end > blockNumber else {
            return 0.0
        }

        return TimeInterval(fundInfo.end - blockNumber) * TimeInterval(blockDuration).seconds
    }
}
