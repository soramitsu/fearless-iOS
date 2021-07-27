import Foundation

struct EraCountdown {
    let activeEra: EraIndex
    let eraLength: SessionIndex
    let sessionLength: SessionIndex
    let eraStartSessionIndex: SessionIndex
    let currentSessionIndex: SessionIndex
    let currentSlot: Slot
    let genesisSlot: Slot
    let blockCreationTime: Moment
    let createdAtDate: Date

    func eraCompletionTime(targetEra: EraIndex) -> TimeInterval {
        guard targetEra > activeEra else { return 0 }

        let numberOfSlotsPerSession = UInt64(sessionLength)
        let currentSessionIndexInt = UInt64(currentSessionIndex)
        let eraLengthInSlots = UInt64(sessionLength * eraLength)

        let sessionStartSlot = currentSessionIndexInt * numberOfSlotsPerSession + genesisSlot
        let sessionProgress = currentSlot - sessionStartSlot
        let eraProgress = (currentSessionIndexInt - UInt64(eraStartSessionIndex)) * numberOfSlotsPerSession
            + sessionProgress
        if Int64(eraLengthInSlots) - Int64(eraProgress) < 0 {
            return 0
        }
        let eraRemained = eraLengthInSlots - eraProgress
        let result = eraRemained * UInt64(blockCreationTime)

        let datesTimeinterval = Date().timeIntervalSince(createdAtDate)
        let activeEraRemainedTime = TimeInterval(result).seconds - datesTimeinterval

        let distanceBetweenEras = targetEra - (activeEra + 1)
        let targetEraDuration = distanceBetweenEras * eraLength * sessionLength * blockCreationTime
        return max(0.0, TimeInterval(targetEraDuration).seconds + activeEraRemainedTime)
    }

    func eraCompletionTime() -> TimeInterval {
        eraCompletionTime(targetEra: activeEra + 1)
    }
}
