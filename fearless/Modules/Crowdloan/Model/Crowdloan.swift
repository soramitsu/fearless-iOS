import Foundation

struct Crowdloan {
    let paraId: ParaId
    let fundInfo: CrowdloanFunds
}

extension Crowdloan {
    func isCompleted(for metadata: CrowdloanMetadata) -> Bool {
        fundInfo.raised >= fundInfo.cap ||
            metadata.blockNumber >= fundInfo.end ||
            metadata.leasingIndex > fundInfo.firstPeriod
    }

    func remainedTime(at blockNumber: BlockNumber, blockDuration: BlockTime) -> TimeInterval {
        max(blockNumber.secondsTo(block: fundInfo.end, blockDuration: blockDuration), 0)
    }
}
