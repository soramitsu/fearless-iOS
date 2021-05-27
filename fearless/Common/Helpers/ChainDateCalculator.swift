import Foundation

struct LeasingTimeInterval {
    let duration: TimeInterval
    let tillDate: Date
}

protocol ChainDateCalculatorProtocol {
    func differenceBetweenLeasingPeriods(
        firstPeriod: LeasingPeriod,
        lastPeriod: LeasingPeriod,
        metadata: CrowdloanMetadata,
        calendar: Calendar
    ) -> LeasingTimeInterval?
}

final class ChainDateCalculator: ChainDateCalculatorProtocol {
    func differenceBetweenLeasingPeriods(
        firstPeriod: LeasingPeriod,
        lastPeriod: LeasingPeriod,
        metadata: CrowdloanMetadata,
        calendar: Calendar
    ) -> LeasingTimeInterval? {
        let firstBlockNumber = firstPeriod * metadata.leasingPeriod
        let lastBlockNumber = (lastPeriod + 1) * metadata.leasingPeriod

        let leasingTimeInterval = firstBlockNumber.secondsTo(
            block: lastBlockNumber,
            blockDuration: metadata.blockDuration
        )

        let firstPeriodStartTimeInterval = metadata.blockNumber.secondsTo(
            block: firstBlockNumber,
            blockDuration: metadata.blockDuration
        )

        guard let firstPeriodDate = calendar.date(
            byAdding: .second,
            value: Int(firstPeriodStartTimeInterval),
            to: Date()
        ) else {
            return nil
        }

        guard let lastPeriodDate = calendar.date(
            byAdding: .second,
            value: Int(leasingTimeInterval),
            to: firstPeriodDate
        ) else {
            return nil
        }

        return LeasingTimeInterval(duration: max(leasingTimeInterval, 0), tillDate: lastPeriodDate)
    }
}
