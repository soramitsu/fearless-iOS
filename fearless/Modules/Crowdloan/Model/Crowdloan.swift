import Foundation

struct Crowdloan {
    let paraId: ParaId
    let fundInfo: CrowdloanFunds
}

extension Crowdloan {
    func isCompleted(for metadata: CrowdloanMetadata, displayInfo: CrowdloanDisplayInfo?) -> Bool {
        if let displayInfo = displayInfo {
            if displayInfo.disabled == true { return true }
            if let endingBlock = displayInfo.endingBlock, metadata.blockNumber >= endingBlock {
                return true
            }
        }

        return fundInfo.raised >= fundInfo.cap ||
            metadata.blockNumber >= fundInfo.end ||
            metadata.leasingIndex > fundInfo.firstPeriod
    }

    func remainedTime(at blockNumber: BlockNumber, blockDuration: BlockTime) -> TimeInterval {
        max(blockNumber.secondsTo(block: fundInfo.end, blockDuration: blockDuration), 0)
    }
}
