import Foundation

struct LeasingTimeInterval {
    let duration: TimeInterval
    let tillDate: Date
}

protocol ChainDateCalculatorProtocol {
    func differenceBetweenLeasingSlots(
        firstSlot: LeasingPeriod,
        lastSlot: LeasingPeriod,
        metadata: CrowdloanMetadata,
        calendar: Calendar
    ) -> LeasingTimeInterval?

    func intervalTillSlot(
        _ slot: LeasingPeriod,
        metadata: CrowdloanMetadata,
        calendar: Calendar
    ) -> LeasingTimeInterval?
}

final class ChainDateCalculator: ChainDateCalculatorProtocol {
    func differenceBetweenLeasingSlots(
        firstSlot: LeasingPeriod,
        lastSlot: LeasingPeriod,
        metadata: CrowdloanMetadata,
        calendar: Calendar
    ) -> LeasingTimeInterval? {
        let firstBlockNumber = firstSlot * metadata.leasingPeriod
        let lastBlockNumber = (lastSlot + 1) * metadata.leasingPeriod

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

    func intervalTillSlot(
        _ slot: LeasingPeriod,
        metadata: CrowdloanMetadata,
        calendar: Calendar
    ) -> LeasingTimeInterval? {
        let blockNumber = slot * metadata.leasingPeriod
        let timeInterval = metadata.blockNumber.secondsTo(block: blockNumber, blockDuration: metadata.blockDuration)

        guard let tillDate = calendar.date(
            byAdding: .second,
            value: Int(timeInterval),
            to: Date()
        ) else {
            return nil
        }

        return LeasingTimeInterval(duration: max(timeInterval, 0), tillDate: tillDate)
    }
}
